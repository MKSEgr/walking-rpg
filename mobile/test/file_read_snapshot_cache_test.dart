import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/core/cache/file_read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/core/cache/read_snapshot_cache.dart';

void main() {
  late Directory directory;
  late DateTime now;
  late FileReadSnapshotCache cache;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'walking-rpg-read-cache-',
    );
    now = DateTime.utc(2026, 7, 27, 12);
    cache = FileReadSnapshotCache(
      directoryProvider: () async => directory,
      clock: () => now,
      maxEntriesPerOwner: 2,
      maxPayloadBytes: 512,
    );
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('saves and restores a versioned server snapshot', () async {
    await cache.write(
      ownerId: 'user-1',
      resource: ReadSnapshotResource.home,
      variant: '2026-07-27',
      payload: jsonEncode(<String, Object?>{'dailySteps': 100}),
      ttl: const Duration(hours: 36),
    );

    final ReadSnapshotCacheEntry? entry = await cache.read(
      ownerId: 'user-1',
      resource: ReadSnapshotResource.home,
      variant: '2026-07-27',
    );

    expect(entry, isNotNull);
    expect(entry!.storedAt, now);
    expect(jsonDecode(entry.payload), <String, dynamic>{'dailySteps': 100});
  });

  test('removes expired entries instead of showing stale state', () async {
    await cache.write(
      ownerId: 'user-1',
      resource: ReadSnapshotResource.home,
      variant: '2026-07-27',
      payload: '{}',
      ttl: const Duration(hours: 1),
    );
    now = now.add(const Duration(hours: 2));

    final ReadSnapshotCacheEntry? entry = await cache.read(
      ownerId: 'user-1',
      resource: ReadSnapshotResource.home,
      variant: '2026-07-27',
    );

    expect(entry, isNull);
  });

  test('keeps only the newest configured number of entries', () async {
    for (int day = 25; day <= 27; day += 1) {
      now = DateTime.utc(2026, 7, day, 12);
      await cache.write(
        ownerId: 'user-1',
        resource: ReadSnapshotResource.home,
        variant: '2026-07-$day',
        payload: jsonEncode(<String, Object?>{'day': day}),
        ttl: const Duration(days: 10),
      );
    }

    expect(
      await cache.read(
        ownerId: 'user-1',
        resource: ReadSnapshotResource.home,
        variant: '2026-07-25',
      ),
      isNull,
    );
    expect(
      await cache.read(
        ownerId: 'user-1',
        resource: ReadSnapshotResource.home,
        variant: '2026-07-26',
      ),
      isNotNull,
    );
    expect(
      await cache.read(
        ownerId: 'user-1',
        resource: ReadSnapshotResource.home,
        variant: '2026-07-27',
      ),
      isNotNull,
    );
  });

  test('restores a valid backup when target is corrupted', () async {
    await cache.write(
      ownerId: 'user-1',
      resource: ReadSnapshotResource.platform,
      variant: 'current',
      payload: jsonEncode(<String, Object?>{'stateVersion': 3}),
      ttl: const Duration(days: 7),
    );
    final File target = await _singleJsonFile(directory);
    final File backup = File('${target.path}.bak');
    await backup.writeAsBytes(await target.readAsBytes(), flush: true);
    await target.writeAsString('{broken', flush: true);

    final ReadSnapshotCacheEntry? entry = await cache.read(
      ownerId: 'user-1',
      resource: ReadSnapshotResource.platform,
      variant: 'current',
    );

    expect(entry, isNotNull);
    expect(jsonDecode(entry!.payload), <String, dynamic>{'stateVersion': 3});
    expect(
      await directory
          .list()
          .where((FileSystemEntity item) => item.path.contains('.corrupt-'))
          .isEmpty,
      isFalse,
    );
  });

  test(
    'restores the newest valid temporary snapshot after interruption',
    () async {
      await cache.write(
        ownerId: 'user-1',
        resource: ReadSnapshotResource.platform,
        variant: 'current',
        payload: jsonEncode(<String, Object?>{'stateVersion': 1}),
        ttl: const Duration(days: 7),
      );
      final File target = await _singleJsonFile(directory);
      final DateTime newerStoredAt = now.add(const Duration(minutes: 1));
      final ReadSnapshotCacheEntry newerEntry = ReadSnapshotCacheEntry(
        ownerId: 'user-1',
        resource: ReadSnapshotResource.platform,
        variant: 'current',
        payload: jsonEncode(<String, Object?>{'stateVersion': 2}),
        storedAt: newerStoredAt,
        expiresAt: newerStoredAt.add(const Duration(days: 7)),
      );
      await File('${target.path}.tmp').writeAsString(
        jsonEncode(<String, Object?>{
          'version': FileReadSnapshotCache.schemaVersion,
          'entries': <Map<String, Object?>>[newerEntry.toJson()],
        }),
        flush: true,
      );

      final ReadSnapshotCacheEntry? restored = await cache.read(
        ownerId: 'user-1',
        resource: ReadSnapshotResource.platform,
        variant: 'current',
      );

      expect(jsonDecode(restored!.payload), <String, dynamic>{
        'stateVersion': 2,
      });
      expect(await File('${target.path}.tmp').exists(), isFalse);
    },
  );

  test('isolates snapshots of different owners', () async {
    await cache.write(
      ownerId: 'user-1',
      resource: ReadSnapshotResource.home,
      variant: 'today',
      payload: jsonEncode(<String, Object?>{'owner': 1}),
      ttl: const Duration(days: 1),
    );
    await cache.write(
      ownerId: 'user-2',
      resource: ReadSnapshotResource.home,
      variant: 'today',
      payload: jsonEncode(<String, Object?>{'owner': 2}),
      ttl: const Duration(days: 1),
    );

    await cache.invalidateOwner(ownerId: 'user-1');

    expect(
      await cache.read(
        ownerId: 'user-1',
        resource: ReadSnapshotResource.home,
        variant: 'today',
      ),
      isNull,
    );
    final ReadSnapshotCacheEntry? second = await cache.read(
      ownerId: 'user-2',
      resource: ReadSnapshotResource.home,
      variant: 'today',
    );
    expect(jsonDecode(second!.payload), <String, dynamic>{'owner': 2});
  });

  test('uses case-insensitive-safe filenames for owners', () async {
    await cache.write(
      ownerId: 'aaa',
      resource: ReadSnapshotResource.home,
      variant: 'today',
      payload: jsonEncode(<String, Object?>{'owner': 'aaa'}),
      ttl: const Duration(days: 1),
    );
    await cache.write(
      ownerId: 'aaG',
      resource: ReadSnapshotResource.home,
      variant: 'today',
      payload: jsonEncode(<String, Object?>{'owner': 'aaG'}),
      ttl: const Duration(days: 1),
    );

    final List<File> files = await directory
        .list()
        .where(
          (FileSystemEntity entity) =>
              entity is File && entity.path.endsWith('.json'),
        )
        .cast<File>()
        .toList();
    final List<String> names = files
        .map((File file) => file.uri.pathSegments.last)
        .toList(growable: false);

    expect(files, hasLength(2));
    expect(names.every((String name) => name == name.toLowerCase()), isTrue);
    expect(
      names.map((String name) => name.toLowerCase()).toSet(),
      hasLength(2),
    );
    expect(
      jsonDecode(
        (await cache.read(
          ownerId: 'aaa',
          resource: ReadSnapshotResource.home,
          variant: 'today',
        ))!.payload,
      ),
      <String, dynamic>{'owner': 'aaa'},
    );
    expect(
      jsonDecode(
        (await cache.read(
          ownerId: 'aaG',
          resource: ReadSnapshotResource.home,
          variant: 'today',
        ))!.payload,
      ),
      <String, dynamic>{'owner': 'aaG'},
    );
  });

  test(
    'quarantines a fully corrupted store and accepts a new snapshot',
    () async {
      await cache.write(
        ownerId: 'user-1',
        resource: ReadSnapshotResource.platform,
        variant: 'current',
        payload: '{}',
        ttl: const Duration(days: 7),
      );
      final File target = await _singleJsonFile(directory);
      await target.writeAsString('{broken', flush: true);
      await File('${target.path}.bak').writeAsString('broken', flush: true);

      expect(
        await cache.read(
          ownerId: 'user-1',
          resource: ReadSnapshotResource.platform,
          variant: 'current',
        ),
        isNull,
      );

      await cache.write(
        ownerId: 'user-1',
        resource: ReadSnapshotResource.platform,
        variant: 'current',
        payload: jsonEncode(<String, Object?>{'stateVersion': 4}),
        ttl: const Duration(days: 7),
      );
      final ReadSnapshotCacheEntry? restored = await cache.read(
        ownerId: 'user-1',
        resource: ReadSnapshotResource.platform,
        variant: 'current',
      );
      expect(jsonDecode(restored!.payload), <String, dynamic>{
        'stateVersion': 4,
      });
    },
  );

  test('rejects an entry belonging to another owner', () async {
    await cache.write(
      ownerId: 'user-1',
      resource: ReadSnapshotResource.home,
      variant: 'today',
      payload: '{}',
      ttl: const Duration(days: 1),
    );
    final File target = await _singleJsonFile(directory);
    final Map<String, dynamic> envelope =
        jsonDecode(await target.readAsString()) as Map<String, dynamic>;
    final List<dynamic> entries = envelope['entries'] as List<dynamic>;
    final Map<String, dynamic> entry = Map<String, dynamic>.from(
      entries.single as Map<dynamic, dynamic>,
    );
    entry['ownerId'] = 'user-2';
    envelope['entries'] = <Map<String, dynamic>>[entry];
    await target.writeAsString(jsonEncode(envelope), flush: true);

    final ReadSnapshotCacheEntry? leaked = await cache.read(
      ownerId: 'user-1',
      resource: ReadSnapshotResource.home,
      variant: 'today',
    );

    expect(leaked, isNull);
    expect(
      await directory
          .list()
          .where((FileSystemEntity item) => item.path.contains('.corrupt-'))
          .isEmpty,
      isFalse,
    );
  });

  test('rejects payloads larger than the configured limit', () async {
    await expectLater(
      cache.write(
        ownerId: 'user-1',
        resource: ReadSnapshotResource.home,
        variant: 'today',
        payload: jsonEncode(<String, Object?>{
          'value': List<String>.filled(600, 'x').join(),
        }),
        ttl: const Duration(hours: 1),
      ),
      throwsA(isA<ReadSnapshotTooLargeException>()),
    );
  });

  test('encodes owner id instead of using it as a path fragment', () async {
    await cache.write(
      ownerId: '../other/user',
      resource: ReadSnapshotResource.home,
      variant: 'today',
      payload: '{}',
      ttl: const Duration(hours: 1),
    );

    final List<FileSystemEntity> files = await directory.list().toList();
    expect(files, hasLength(1));
    expect(File(files.single.path).parent.path, directory.path);
    expect(files.single.path, isNot(contains('../')));
  });

  test('can invalidate only home while retaining platform snapshot', () async {
    await cache.write(
      ownerId: 'user-1',
      resource: ReadSnapshotResource.home,
      variant: 'today',
      payload: '{}',
      ttl: const Duration(days: 1),
    );
    await cache.write(
      ownerId: 'user-1',
      resource: ReadSnapshotResource.platform,
      variant: 'current',
      payload: '{}',
      ttl: const Duration(days: 1),
    );

    await cache.invalidateOwner(
      ownerId: 'user-1',
      resources: const <ReadSnapshotResource>{ReadSnapshotResource.home},
    );

    expect(
      await cache.read(
        ownerId: 'user-1',
        resource: ReadSnapshotResource.home,
        variant: 'today',
      ),
      isNull,
    );
    expect(
      await cache.read(
        ownerId: 'user-1',
        resource: ReadSnapshotResource.platform,
        variant: 'current',
      ),
      isNotNull,
    );
  });
}

Future<File> _singleJsonFile(Directory directory) async {
  final List<File> files = await directory
      .list()
      .where(
        (FileSystemEntity entity) =>
            entity is File && entity.path.endsWith('.json'),
      )
      .cast<File>()
      .toList();
  expect(files, hasLength(1));
  return files.single;
}
