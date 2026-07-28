import 'package:walking_rpg_mobile/core/cache/read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command_store.dart';

abstract interface class LocalStateCleaner {
  Future<void> clear(String ownerId);
}

final class OwnerLocalStateCleaner implements LocalStateCleaner {
  const OwnerLocalStateCleaner({
    required ReadSnapshotCache cache,
    required MobileCommandStore commandStore,
  }) : _cache = cache,
       _commandStore = commandStore;

  final ReadSnapshotCache _cache;
  final MobileCommandStore _commandStore;

  @override
  Future<void> clear(String ownerId) async {
    Object? firstError;
    StackTrace? firstStackTrace;
    try {
      await clearReadSnapshotsForOwner(_cache, ownerId: ownerId);
    } on Object catch (error, stackTrace) {
      firstError = error;
      firstStackTrace = stackTrace;
    }

    try {
      await _commandStore.deleteOwner(ownerId);
    } on Object catch (error, stackTrace) {
      firstError ??= error;
      firstStackTrace ??= stackTrace;
    }

    if (firstError != null && firstStackTrace != null) {
      Error.throwWithStackTrace(
        OwnerLocalStateCleanupException(firstError),
        firstStackTrace,
      );
    }
  }
}

final class OwnerLocalStateCleanupException implements Exception {
  const OwnerLocalStateCleanupException(this.cause);

  final Object cause;

  @override
  String toString() => 'Не удалось полностью очистить локальные данные';
}
