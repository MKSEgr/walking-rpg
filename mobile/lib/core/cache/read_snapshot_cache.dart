import 'dart:convert';

/// Server-confirmed snapshots that may be reused for read-only offline display.
enum ReadSnapshotResource {
  home('home'),
  platform('platform');

  const ReadSnapshotResource(this.wireName);

  final String wireName;
}

/// Metadata attached to a domain snapshot restored from the local read cache.
final class CachedReadMetadata {
  const CachedReadMetadata({required this.cachedAt, required this.reason});

  final DateTime cachedAt;
  final String reason;
}

/// Captures the mutation generation that was current when a read request began.
///
/// A successful response may update the local read cache only while this token
/// is still current. Every mutation advances the generation before touching
/// the cache, so an older in-flight GET cannot recreate an invalidated entry.
final class ReadSnapshotGenerationToken {
  const ReadSnapshotGenerationToken._({
    required this.ownerId,
    required this.generation,
  });

  final String ownerId;
  final int generation;
}

final class ReadSnapshotCacheEntry {
  const ReadSnapshotCacheEntry({
    required this.ownerId,
    required this.resource,
    required this.variant,
    required this.payload,
    required this.storedAt,
    required this.expiresAt,
  });

  factory ReadSnapshotCacheEntry.fromJson(Map<String, Object?> json) {
    final String resourceName = _requireText(json['resource'], 'resource');
    final ReadSnapshotResource resource =
        ReadSnapshotResource.values
            .where(
              (ReadSnapshotResource value) => value.wireName == resourceName,
            )
            .firstOrNull ??
        (throw FormatException('Неизвестный cached resource: $resourceName'));
    final String payload = _requireText(json['payload'], 'payload');
    final Object? decodedPayload = jsonDecode(payload);
    if (decodedPayload is! Map<Object?, Object?>) {
      throw const FormatException('Cached payload должен быть JSON-объектом');
    }
    final DateTime storedAt = _readInstant(json['storedAt'], 'storedAt');
    final DateTime expiresAt = _readInstant(json['expiresAt'], 'expiresAt');
    if (!expiresAt.isAfter(storedAt)) {
      throw const FormatException('expiresAt должен быть позже storedAt');
    }
    return ReadSnapshotCacheEntry(
      ownerId: _requireText(json['ownerId'], 'ownerId'),
      resource: resource,
      variant: _requireText(json['variant'], 'variant'),
      payload: payload,
      storedAt: storedAt,
      expiresAt: expiresAt,
    );
  }

  final String ownerId;
  final ReadSnapshotResource resource;
  final String variant;
  final String payload;
  final DateTime storedAt;
  final DateTime expiresAt;

  bool isExpiredAt(DateTime instant) => !expiresAt.isAfter(instant.toUtc());

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'ownerId': ownerId,
      'resource': resource.wireName,
      'variant': variant,
      'payload': payload,
      'storedAt': storedAt.toUtc().toIso8601String(),
      'expiresAt': expiresAt.toUtc().toIso8601String(),
    };
  }

  static String _requireText(Object? value, String field) {
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$field должен быть непустой строкой');
    }
    return value;
  }

  static DateTime _readInstant(Object? value, String field) {
    if (value is! String) {
      throw FormatException('$field должен быть строкой date-time');
    }
    final DateTime? parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw FormatException('$field содержит некорректный date-time');
    }
    return parsed.toUtc();
  }
}

final Map<String, int> _readSnapshotGenerations = <String, int>{};

ReadSnapshotGenerationToken captureReadSnapshotGeneration(String ownerId) {
  final String normalizedOwnerId = _normalizeOwnerId(ownerId);
  return ReadSnapshotGenerationToken._(
    ownerId: normalizedOwnerId,
    generation: _readSnapshotGenerations[normalizedOwnerId] ?? 0,
  );
}

bool isReadSnapshotGenerationCurrent(ReadSnapshotGenerationToken token) {
  return (_readSnapshotGenerations[token.ownerId] ?? 0) == token.generation;
}

Future<void> invalidateReadSnapshotsBeforeMutation(
  ReadSnapshotCache? cache, {
  required String ownerId,
  Set<ReadSnapshotResource>? resources,
}) async {
  final String normalizedOwnerId = _normalizeOwnerId(ownerId);
  _readSnapshotGenerations[normalizedOwnerId] =
      (_readSnapshotGenerations[normalizedOwnerId] ?? 0) + 1;
  if (cache == null) {
    return;
  }
  try {
    await cache.invalidateOwner(
      ownerId: normalizedOwnerId,
      resources: resources,
    );
  } on Object catch (error, stackTrace) {
    Error.throwWithStackTrace(
      ReadSnapshotCacheException(
        'Не удалось безопасно очистить локальное состояние перед отправкой команды',
        cause: error,
      ),
      stackTrace,
    );
  }
}

final class ReadSnapshotCacheException implements Exception {
  const ReadSnapshotCacheException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

abstract interface class ReadSnapshotCache {
  Future<ReadSnapshotCacheEntry?> read({
    required String ownerId,
    required ReadSnapshotResource resource,
    required String variant,
  });

  Future<void> write({
    required String ownerId,
    required ReadSnapshotResource resource,
    required String variant,
    required String payload,
    required Duration ttl,
  });

  Future<void> remove({
    required String ownerId,
    required ReadSnapshotResource resource,
    required String variant,
  });

  Future<void> invalidateOwner({
    required String ownerId,
    Set<ReadSnapshotResource>? resources,
  });
}

String _normalizeOwnerId(String value) {
  final String normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, 'ownerId', 'Значение обязательно');
  }
  return normalized;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final Iterator<T> iterator = this.iterator;
    if (!iterator.moveNext()) {
      return null;
    }
    return iterator.current;
  }
}
