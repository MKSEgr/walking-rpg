import 'package:walking_rpg_mobile/core/commands/mobile_command.dart';

final class MobileCommandRecoverySnapshot {
  MobileCommandRecoverySnapshot(Iterable<MobileCommandRecoveryItem> items)
    : items = List<MobileCommandRecoveryItem>.unmodifiable(items);

  final List<MobileCommandRecoveryItem> items;

  int get pendingCount => items
      .where(
        (MobileCommandRecoveryItem item) =>
            item.state == MobileCommandState.pending,
      )
      .length;

  int get failedCount => items
      .where(
        (MobileCommandRecoveryItem item) =>
            item.state == MobileCommandState.failed,
      )
      .length;

  int get totalCount => items.length;
}

final class MobileCommandRecoveryItem {
  MobileCommandRecoveryItem.fromCommand(MobileCommand command)
    : _commandId = command.commandId,
      type = command.type,
      lane = command.lane,
      state = command.state,
      attemptCount = command.attemptCount,
      createdAt = command.createdAt,
      updatedAt = command.updatedAt,
      lastAttemptAt = command.lastAttemptAt,
      failureCategory = command.lastFailureCategory;

  final String _commandId;
  final MobileCommandType type;
  final MobileCommandLane lane;
  final MobileCommandState state;
  final int attemptCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastAttemptAt;
  final MobileCommandFailureCategory? failureCategory;

  bool refersTo(MobileCommand command) {
    return _commandId == command.commandId &&
        createdAt == command.createdAt &&
        updatedAt == command.updatedAt &&
        attemptCount == command.attemptCount &&
        state == command.state;
  }

  int compareStableIdentity(MobileCommandRecoveryItem other) {
    return _commandId.compareTo(other._commandId);
  }

  @override
  bool operator ==(Object other) {
    return other is MobileCommandRecoveryItem && other._commandId == _commandId;
  }

  @override
  int get hashCode => _commandId.hashCode;
}

final class MobileCommandDismissalException implements Exception {
  const MobileCommandDismissalException();

  @override
  String toString() {
    return 'Сохранённое действие всё ещё ожидает отправки '
        'и не может быть удалено';
  }
}

final class MobileCommandRecoveryUnavailableException implements Exception {
  const MobileCommandRecoveryUnavailableException();

  @override
  String toString() {
    return 'Локальная очередь сохранённых действий недоступна';
  }
}
