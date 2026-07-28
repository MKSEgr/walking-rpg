import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:walking_rpg_mobile/core/cache/read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/core/commands/async_lock.dart';

typedef ReadCacheDirectoryProvider = Future<Directory> Function();
typedef ReadCacheClock = DateTime Function();

final class FileReadSnapshotCache implements ReadSnapshotCache {
  FileReadSnapshotCache({
    required ReadCacheDirectoryProvider directoryProvider,
    ReadCacheClock? clock,
    this.maxEntriesPerOwner = 32,
    this.maxPayloadBytes = 1024 * 1024,
    this.filePrefix = 'walking_rpg_read_cache_v1',
  }) : _directoryProvider = directoryProvider,
       _clock = clock ?? DateTime.now {
    if (maxEntriesPerOwner <= 0) {
      throw ArgumentError.value(
        maxEntriesPerOwner,
        'maxEntriesPerOwner',
        'Значение должно быть положительным',
      );
    }
    if (maxPayloadBytes <= 0) {
      throw ArgumentError.value(
        maxPayloadBytes,
        'maxPayloadBytes',
        'Значение должно быть положительным',
      );
    }
  }

  factory FileReadSnapshotCache.fromEnvironment() {
    return FileReadSnapshotCache(
      directoryProvider: getApplicationSupportDirectory,
    );
  }

  static const int schemaVersion = 1;
  static final Map<String, AsyncLock> _pathLocks = <String, AsyncLock>{};

  final ReadCacheDirectoryProvider _directoryProvider;
  final ReadCacheClock _clock;
  final int maxEntriesPerOwner;
  final int maxPayloadBytes;
  final String filePrefix;

  @override
  Future<ReadSnapshotCacheEntry?> read({
    required String ownerId,
    required ReadSnapshotResource resource,
    required String variant,
  }) async {
    final _CacheLocation location = await _location(ownerId);
    return _lockFor(
      location.target.path,
    ).run<ReadSnapshotCacheEntry?>(() async {
      final DateTime now = _clock().toUtc();
      final List<ReadSnapshotCacheEntry> loaded = await _load(location);
      final List<ReadSnapshotCacheEntry> active = loaded
          .where((ReadSnapshotCacheEntry entry) => !entry.isExpiredAt(now))
          .toList(growable: false);
      if (active.length != loaded.length) {
        await _save(location, active);
      }
      final String normalizedVariant = _normalizeVariant(variant);
      for (final ReadSnapshotCacheEntry entry in active) {
        if (entry.resource == resource && entry.variant == normalizedVariant) {
          return entry;
        }
      }
      return null;
    });
  }

  @override
  Future<void> write({
    required String ownerId,
    required ReadSnapshotResource resource,
    required String variant,
    required String payload,
    required Duration ttl,
  }) async {
    if (ttl.inMicroseconds <= 0) {
      throw ArgumentError.value(ttl, 'ttl', 'TTL должен быть положительным');
    }
    final String normalizedPayload = _validatePayload(payload);
    final int payloadBytes = utf8.encode(normalizedPayload).length;
    if (payloadBytes > maxPayloadBytes) {
      throw ReadSnapshotTooLargeException(
        actualBytes: payloadBytes,
        maxBytes: maxPayloadBytes,
      );
    }
    final _CacheLocation location = await _location(ownerId);
    await _lockFor(location.target.path).run<void>(() async {
      final DateTime now = _clock().toUtc();
      final String normalizedVariant = _normalizeVariant(variant);
      final List<ReadSnapshotCacheEntry> entries = (await _load(location))
          .where((ReadSnapshotCacheEntry entry) => !entry.isExpiredAt(now))
          .where(
            (ReadSnapshotCacheEntry entry) =>
                entry.resource != resource ||
                entry.variant != normalizedVariant,
          )
          .toList(growable: true);
      entries.add(
        ReadSnapshotCacheEntry(
          ownerId: _normalizeOwner(ownerId),
          resource: resource,
          variant: normalizedVariant,
          payload: normalizedPayload,
          storedAt: now,
          expiresAt: now.add(ttl),
        ),
      );
      entries.sort(
        (ReadSnapshotCacheEntry left, ReadSnapshotCacheEntry right) =>
            right.storedAt.compareTo(left.storedAt),
      );
      final List<ReadSnapshotCacheEntry> retained =
          entries.length <= maxEntriesPerOwner
          ? entries
          : entries.take(maxEntriesPerOwner).toList(growable: false);
      await _save(location, retained);
    });
  }

  @override
  Future<void> remove({
    required String ownerId,
    required ReadSnapshotResource resource,
    required String variant,
  }) async {
    final _CacheLocation location = await _location(ownerId);
    await _lockFor(location.target.path).run<void>(() async {
      final String normalizedVariant = _normalizeVariant(variant);
      final List<ReadSnapshotCacheEntry> loaded = await _load(location);
      final List<ReadSnapshotCacheEntry> retained = loaded
          .where(
            (ReadSnapshotCacheEntry entry) =>
                entry.resource != resource ||
                entry.variant != normalizedVariant,
          )
          .toList(growable: false);
      if (retained.length != loaded.length) {
        await _save(location, retained);
      }
    });
  }

  @override
  Future<void> invalidateOwner({
    required String ownerId,
    Set<ReadSnapshotResource>? resources,
  }) async {
    final _CacheLocation location = await _location(ownerId);
    await _lockFor(location.target.path).run<void>(() async {
      if (resources == null || resources.isEmpty) {
        await _deleteIfExists(location.target);
        await _deleteIfExists(location.temporary);
        await _deleteIfExists(location.backup);
        return;
      }
      final List<ReadSnapshotCacheEntry> loaded = await _load(location);
      final List<ReadSnapshotCacheEntry> retained = loaded
          .where(
            (ReadSnapshotCacheEntry entry) =>
                !resources.contains(entry.resource),
          )
          .toList(growable: false);
      if (retained.length != loaded.length) {
        await _save(location, retained);
      }
    });
  }

  int get _maxStoreBytes {
    return (maxPayloadBytes + 2048) * maxEntriesPerOwner + 4096;
  }

  Future<_CacheLocation> _location(String ownerId) async {
    final String normalizedOwner = _normalizeOwner(ownerId);
    final Directory directory = await _directoryProvider();
    await directory.create(recursive: true);
    final String encodedOwner = base64Url
        .encode(utf8.encode(normalizedOwner))
        .replaceAll('=', '');
    final String safeName = '$filePrefix-$encodedOwner.json';
    if (safeName.contains('/') || safeName.contains('\\')) {
      throw const FormatException('Некорректное имя cache-файла');
    }
    final File target = File(_path(directory, safeName));
    return _CacheLocation(
      ownerId: normalizedOwner,
      target: target,
      temporary: File('${target.path}.tmp'),
      backup: File('${target.path}.bak'),
    );
  }

  Future<List<ReadSnapshotCacheEntry>> _load(_CacheLocation location) async {
    final List<File> candidates = <File>[
      if (await location.target.exists()) location.target,
      if (await location.temporary.exists()) location.temporary,
      if (await location.backup.exists()) location.backup,
    ];
    if (candidates.isEmpty) {
      return <ReadSnapshotCacheEntry>[];
    }

    final List<File> invalid = <File>[];
    final List<_DecodedCacheCandidate> valid = <_DecodedCacheCandidate>[];
    for (final File candidate in candidates) {
      try {
        if (await candidate.length() > _maxStoreBytes) {
          throw const FormatException('Read cache превышает допустимый размер');
        }
        final List<ReadSnapshotCacheEntry> entries = _decode(
          await candidate.readAsString(),
          expectedOwnerId: location.ownerId,
        );
        final DateTime modifiedAt = (await candidate.lastModified()).toUtc();
        final DateTime freshness = entries.isEmpty
            ? modifiedAt
            : entries
                  .map((ReadSnapshotCacheEntry entry) => entry.storedAt)
                  .reduce(
                    (DateTime left, DateTime right) =>
                        left.isAfter(right) ? left : right,
                  );
        valid.add(
          _DecodedCacheCandidate(
            file: candidate,
            entries: entries,
            freshness: freshness,
          ),
        );
      } on Object {
        invalid.add(candidate);
      }
    }

    for (final File corrupt in invalid) {
      await _quarantine(corrupt);
    }
    if (valid.isEmpty) {
      return <ReadSnapshotCacheEntry>[];
    }

    valid.sort(
      (_DecodedCacheCandidate left, _DecodedCacheCandidate right) =>
          right.freshness.compareTo(left.freshness),
    );
    final _DecodedCacheCandidate selected = valid.first;
    if (selected.file.path != location.target.path) {
      await _restore(candidate: selected.file, location: location);
    }
    await _deleteIfExists(location.temporary);
    await _deleteIfExists(location.backup);
    return selected.entries;
  }

  Future<void> _save(
    _CacheLocation location,
    List<ReadSnapshotCacheEntry> entries,
  ) async {
    if (entries.isEmpty) {
      await _deleteIfExists(location.target);
      await _deleteIfExists(location.temporary);
      await _deleteIfExists(location.backup);
      return;
    }
    final String encoded = jsonEncode(<String, Object?>{
      'version': schemaVersion,
      'entries': entries
          .map<Map<String, Object?>>(
            (ReadSnapshotCacheEntry entry) => entry.toJson(),
          )
          .toList(growable: false),
    });
    await _deleteIfExists(location.temporary);
    await location.temporary.writeAsString(encoded, flush: true);

    await _deleteIfExists(location.backup);
    if (await location.target.exists()) {
      await location.target.rename(location.backup.path);
    }
    try {
      await location.temporary.rename(location.target.path);
      await _deleteIfExists(location.backup);
    } on Object {
      if (!await location.target.exists() && await location.backup.exists()) {
        await location.backup.rename(location.target.path);
      }
      rethrow;
    }
  }

  List<ReadSnapshotCacheEntry> _decode(
    String encoded, {
    required String expectedOwnerId,
  }) {
    final Object? decoded = jsonDecode(encoded);
    if (decoded is! Map<Object?, Object?>) {
      throw const FormatException('Read cache должен быть JSON-объектом');
    }
    final Map<String, Object?> envelope = decoded.map<String, Object?>((
      Object? key,
      Object? value,
    ) {
      if (key is! String) {
        throw const FormatException('Ключи read cache должны быть строками');
      }
      return MapEntry<String, Object?>(key, value);
    });
    if (envelope['version'] != schemaVersion) {
      throw FormatException(
        'Неподдерживаемая версия read cache: ${envelope['version']}',
      );
    }
    final Object? rawEntries = envelope['entries'];
    if (rawEntries is! List<Object?>) {
      throw const FormatException('entries должен быть JSON-массивом');
    }
    return rawEntries
        .map<ReadSnapshotCacheEntry>((Object? item) {
          if (item is! Map<Object?, Object?>) {
            throw const FormatException('Элемент entries должен быть объектом');
          }
          final Map<String, Object?> json = item.map<String, Object?>((
            Object? key,
            Object? value,
          ) {
            if (key is! String) {
              throw const FormatException(
                'Ключи cache entry должны быть строками',
              );
            }
            return MapEntry<String, Object?>(key, value);
          });
          final ReadSnapshotCacheEntry entry = ReadSnapshotCacheEntry.fromJson(
            json,
          );
          if (entry.ownerId != expectedOwnerId) {
            throw const FormatException(
              'Cache entry принадлежит другому пользователю',
            );
          }
          return entry;
        })
        .toList(growable: false);
  }

  Future<void> _restore({
    required File candidate,
    required _CacheLocation location,
  }) async {
    final List<int> bytes = await candidate.readAsBytes();
    await _deleteIfExists(location.target);
    await location.target.writeAsBytes(bytes, flush: true);
    if (candidate.path != location.target.path) {
      await _deleteIfExists(candidate);
    }
  }

  Future<void> _quarantine(File file) async {
    if (!await file.exists()) {
      return;
    }
    final String suffix = _clock().toUtc().microsecondsSinceEpoch.toString();
    String target = '${file.path}.corrupt-$suffix';
    int collision = 0;
    while (await File(target).exists()) {
      collision += 1;
      target = '${file.path}.corrupt-$suffix-$collision';
    }
    await file.rename(target);
  }

  Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  String _validatePayload(String payload) {
    final String normalized = payload.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(payload, 'payload', 'Payload обязателен');
    }
    final Object? decoded = jsonDecode(normalized);
    if (decoded is! Map<Object?, Object?>) {
      throw const FormatException('Cached payload должен быть JSON-объектом');
    }
    return normalized;
  }

  String _normalizeOwner(String ownerId) {
    final String normalized = ownerId.trim();
    if (normalized.isEmpty || utf8.encode(normalized).length > 128) {
      throw ArgumentError.value(
        ownerId,
        'ownerId',
        'Owner обязателен и не должен превышать 128 байт UTF-8',
      );
    }
    return normalized;
  }

  String _normalizeVariant(String variant) {
    final String normalized = variant.trim();
    if (normalized.isEmpty || normalized.length > 128) {
      throw ArgumentError.value(
        variant,
        'variant',
        'Variant обязателен и не должен превышать 128 символов',
      );
    }
    return normalized;
  }

  AsyncLock _lockFor(String path) {
    return _pathLocks.putIfAbsent(path, AsyncLock.new);
  }

  String _path(Directory directory, String name) {
    return '${directory.path}${Platform.pathSeparator}$name';
  }
}

final class _CacheLocation {
  const _CacheLocation({
    required this.ownerId,
    required this.target,
    required this.temporary,
    required this.backup,
  });

  final String ownerId;
  final File target;
  final File temporary;
  final File backup;
}

final class _DecodedCacheCandidate {
  const _DecodedCacheCandidate({
    required this.file,
    required this.entries,
    required this.freshness,
  });

  final File file;
  final List<ReadSnapshotCacheEntry> entries;
  final DateTime freshness;
}

final class ReadSnapshotTooLargeException implements Exception {
  const ReadSnapshotTooLargeException({
    required this.actualBytes,
    required this.maxBytes,
  });

  final int actualBytes;
  final int maxBytes;

  @override
  String toString() {
    return 'Cached snapshot слишком большой: $actualBytes байт при лимите '
        '$maxBytes байт';
  }
}
