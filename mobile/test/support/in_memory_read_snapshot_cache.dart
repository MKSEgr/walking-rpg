import 'dart:io';

import 'package:walking_rpg_mobile/core/cache/read_snapshot_cache.dart';

final class InMemoryReadSnapshotCache implements ReadSnapshotCache {
  InMemoryReadSnapshotCache({
    DateTime Function()? clock,
    this.failInvalidation = false,
  }) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final bool failInvalidation;
  final Map<String, ReadSnapshotCacheEntry> _entries =
      <String, ReadSnapshotCacheEntry>{};

  int writes = 0;
  int removals = 0;
  int invalidations = 0;

  @override
  Future<ReadSnapshotCacheEntry?> read({
    required String ownerId,
    required ReadSnapshotResource resource,
    required String variant,
  }) async {
    final String key = _key(ownerId, resource, variant);
    final ReadSnapshotCacheEntry? entry = _entries[key];
    if (entry != null && entry.isExpiredAt(_clock())) {
      _entries.remove(key);
      return null;
    }
    return entry;
  }

  @override
  Future<void> write({
    required String ownerId,
    required ReadSnapshotResource resource,
    required String variant,
    required String payload,
    required Duration ttl,
  }) async {
    final DateTime now = _clock().toUtc();
    _entries[_key(ownerId, resource, variant)] = ReadSnapshotCacheEntry(
      ownerId: ownerId,
      resource: resource,
      variant: variant,
      payload: payload,
      storedAt: now,
      expiresAt: now.add(ttl),
    );
    writes += 1;
  }

  @override
  Future<void> remove({
    required String ownerId,
    required ReadSnapshotResource resource,
    required String variant,
  }) async {
    _entries.remove(_key(ownerId, resource, variant));
    removals += 1;
  }

  @override
  Future<void> invalidateOwner({
    required String ownerId,
    Set<ReadSnapshotResource>? resources,
  }) async {
    if (failInvalidation) {
      throw const FileSystemException('cache invalidation failed');
    }
    _entries.removeWhere((String key, ReadSnapshotCacheEntry entry) {
      return entry.ownerId == ownerId &&
          (resources == null ||
              resources.isEmpty ||
              resources.contains(entry.resource));
    });
    invalidations += 1;
  }

  String _key(String ownerId, ReadSnapshotResource resource, String variant) {
    return '$ownerId|${resource.wireName}|$variant';
  }
}
