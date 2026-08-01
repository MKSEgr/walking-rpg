import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:walking_rpg_mobile/core/commands/async_lock.dart';
import 'package:walking_rpg_mobile/core/commands/file_mobile_command_store.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command_recovery.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command_store.dart';
import 'package:walking_rpg_mobile/core/config/app_environment.dart';
import 'package:walking_rpg_mobile/features/activity/data/activity_api_client.dart';
import 'package:walking_rpg_mobile/features/activity/domain/activity_sync_result.dart';
import 'package:walking_rpg_mobile/features/activity/domain/step_reading.dart';
import 'package:walking_rpg_mobile/features/crafting/data/crafting_api_client.dart';
import 'package:walking_rpg_mobile/features/crafting/domain/crafting_result.dart';
import 'package:walking_rpg_mobile/features/event/data/event_api_client.dart';
import 'package:walking_rpg_mobile/features/event/domain/event_resolution_result.dart';
import 'package:walking_rpg_mobile/features/expedition/data/expedition_api_client.dart';
import 'package:walking_rpg_mobile/features/expedition/domain/expedition_advance_result.dart';
import 'package:walking_rpg_mobile/features/platform/data/platform_api_client.dart';
import 'package:walking_rpg_mobile/features/platform/domain/platform_command_result.dart';

typedef MobileCommandClock = DateTime Function();
typedef MobileCommandKeyFactory =
    String Function(MobileCommandType type, DateTime now);
typedef ActivityCommandSender =
    Future<ActivitySyncResult> Function({
      required StepReading reading,
      required String idempotencyKey,
    });
typedef ExpeditionCommandSender =
    Future<ExpeditionAdvanceResult> Function({
      required String expeditionId,
      required int energyToSpend,
      required String idempotencyKey,
    });
typedef EventCommandSender =
    Future<EventResolutionResult> Function({
      required String eventId,
      required String choiceId,
      required String idempotencyKey,
    });
typedef EventResultAcknowledgementSender =
    Future<EventResultAcknowledgement> Function({required String receiptId});
typedef CraftingCommandSender =
    Future<CraftingResult> Function({
      required String recipeId,
      required String idempotencyKey,
    });
typedef PlatformCommandSender =
    Future<PlatformCommandResult> Function({
      required String commandType,
      required Map<String, Object?> payload,
      required String idempotencyKey,
    });

final class MobileCommandRuntime {
  MobileCommandRuntime({
    required String ownerId,
    required MobileCommandStore store,
    required ActivityCommandSender activitySender,
    required ExpeditionCommandSender expeditionSender,
    required EventCommandSender eventSender,
    EventResultAcknowledgementSender? eventResultAcknowledgementSender,
    CraftingCommandSender? craftingSender,
    PlatformCommandSender? platformSender,
    MobileCommandClock? clock,
    MobileCommandKeyFactory? keyFactory,
  }) : ownerId = _requireText(ownerId, 'ownerId'),
       _store = store,
       _activitySender = activitySender,
       _expeditionSender = expeditionSender,
       _eventSender = eventSender,
       _eventResultAcknowledgementSender = eventResultAcknowledgementSender,
       _craftingSender = craftingSender,
       _platformSender = platformSender,
       _clock = clock ?? DateTime.now,
       _keyFactory = keyFactory ?? _defaultKey;

  factory MobileCommandRuntime.fromEnvironment() {
    final ActivityApiClient activityClient =
        ActivityApiClient.fromEnvironment();
    final ExpeditionApiClient expeditionClient =
        ExpeditionApiClient.fromEnvironment();
    final EventApiClient eventClient = EventApiClient.fromEnvironment();
    final CraftingApiClient craftingClient =
        CraftingApiClient.fromEnvironment();
    final PlatformApiClient platformClient =
        PlatformApiClient.fromEnvironment();
    return MobileCommandRuntime(
      ownerId: AppEnvironment.demoUserId,
      store: FileMobileCommandStore.fromEnvironment(),
      activitySender: activityClient.sync,
      expeditionSender: expeditionClient.advance,
      eventSender: eventClient.resolve,
      eventResultAcknowledgementSender: eventClient.acknowledge,
      craftingSender: craftingClient.craft,
      platformSender: platformClient.execute,
    );
  }

  final String ownerId;
  final MobileCommandStore _store;
  final ActivityCommandSender _activitySender;
  final ExpeditionCommandSender _expeditionSender;
  final EventCommandSender _eventSender;
  final EventResultAcknowledgementSender? _eventResultAcknowledgementSender;
  final CraftingCommandSender? _craftingSender;
  final PlatformCommandSender? _platformSender;
  final MobileCommandClock _clock;
  final MobileCommandKeyFactory _keyFactory;
  final StreamController<void> _changesController =
      StreamController<void>.broadcast(sync: true);
  final AsyncLock _stateLock = AsyncLock();
  final Map<MobileCommandLane, AsyncLock> _laneLocks =
      <MobileCommandLane, AsyncLock>{
        MobileCommandLane.activity: AsyncLock(),
        MobileCommandLane.gameplay: AsyncLock(),
        MobileCommandLane.telemetry: AsyncLock(),
      };
  bool _closed = false;
  int _activeOperations = 0;
  Completer<void>? _idleCompleter;
  Future<void>? _closeFuture;
  Future<MobileCommandReplayReport>? _startupReplay;
  bool _startupReplayClaimed = false;
  Future<void>? _startupTelemetryReplay;

  Future<ActivitySyncResult> syncActivity({
    required StepReading reading,
    required String idempotencyKey,
  }) {
    return _runOpenOperation<ActivitySyncResult>(
      () => _submit<ActivitySyncResult>(
        type: MobileCommandType.activitySync,
        proposedKey: idempotencyKey,
        fingerprint: jsonEncode(<Object?>[
          MobileCommandType.activitySync.wireName,
          reading.localDateIso,
          reading.timeZone,
          reading.authoritativeTotal,
          reading.syncCursor,
        ]),
        payload: reading.toJson(),
      ),
    );
  }

  Future<ExpeditionAdvanceResult> advance({
    required String expeditionId,
    required int energyToSpend,
    required String idempotencyKey,
  }) {
    final String normalizedExpeditionId = _requireText(
      expeditionId,
      'expeditionId',
    );
    if (energyToSpend <= 0) {
      throw ArgumentError.value(
        energyToSpend,
        'energyToSpend',
        'Значение должно быть положительным',
      );
    }
    return _runOpenOperation<ExpeditionAdvanceResult>(
      () => _submit<ExpeditionAdvanceResult>(
        type: MobileCommandType.expeditionAdvance,
        proposedKey: idempotencyKey,
        fingerprint: jsonEncode(<Object?>[
          MobileCommandType.expeditionAdvance.wireName,
          normalizedExpeditionId,
          energyToSpend,
        ]),
        payload: <String, Object?>{
          'expeditionId': normalizedExpeditionId,
          'energyToSpend': energyToSpend,
        },
      ),
    );
  }

  Future<EventResolutionResult> resolve({
    required String eventId,
    required String choiceId,
    required String idempotencyKey,
  }) {
    final String normalizedEventId = _requireText(eventId, 'eventId');
    final String normalizedChoiceId = _requireText(choiceId, 'choiceId');
    return _runOpenOperation<EventResolutionResult>(
      () => _submit<EventResolutionResult>(
        type: MobileCommandType.eventResolution,
        proposedKey: idempotencyKey,
        fingerprint: jsonEncode(<Object?>[
          MobileCommandType.eventResolution.wireName,
          normalizedEventId,
          normalizedChoiceId,
        ]),
        payload: <String, Object?>{
          'eventId': normalizedEventId,
          'choiceId': normalizedChoiceId,
        },
      ),
    );
  }

  Future<EventResultAcknowledgement> acknowledgeEventResult({
    required String receiptId,
    required String idempotencyKey,
  }) {
    final String normalizedReceiptId = _requireText(receiptId, 'receiptId');
    return _runOpenOperation<EventResultAcknowledgement>(
      () => _submit<EventResultAcknowledgement>(
        type: MobileCommandType.eventResultAcknowledgement,
        proposedKey: idempotencyKey,
        fingerprint: jsonEncode(<Object?>[
          MobileCommandType.eventResultAcknowledgement.wireName,
          normalizedReceiptId,
        ]),
        payload: <String, Object?>{'receiptId': normalizedReceiptId},
      ),
    );
  }

  Future<CraftingResult> craft({
    required String recipeId,
    required String idempotencyKey,
  }) {
    final String normalizedRecipeId = _requireText(recipeId, 'recipeId');
    return _runOpenOperation<CraftingResult>(
      () => _submit<CraftingResult>(
        type: MobileCommandType.crafting,
        proposedKey: idempotencyKey,
        fingerprint: jsonEncode(<Object?>[
          MobileCommandType.crafting.wireName,
          normalizedRecipeId,
        ]),
        payload: <String, Object?>{'recipeId': normalizedRecipeId},
      ),
    );
  }

  Future<PlatformCommandResult> executePlatform({
    required String commandType,
    required Map<String, Object?> payload,
    required String idempotencyKey,
  }) {
    final String normalizedCommandType = _requireText(
      commandType,
      'commandType',
    ).toUpperCase();
    final Map<String, Object?> canonicalPayload = _canonicalMap(payload);
    return _runOpenOperation<PlatformCommandResult>(
      () => _submit<PlatformCommandResult>(
        type: MobileCommandType.platformCommand,
        proposedKey: idempotencyKey,
        fingerprint: jsonEncode(<Object?>[
          MobileCommandType.platformCommand.wireName,
          normalizedCommandType,
          canonicalPayload,
        ]),
        payload: <String, Object?>{
          'commandType': normalizedCommandType,
          'payload': canonicalPayload,
        },
      ),
    );
  }

  Future<MobileCommandReplayReport> replayPending() {
    return _runOpenOperation<MobileCommandReplayReport>(
      () => _runRecoveryOperation(_replayPending),
    );
  }

  Future<MobileCommandReplayReport> replayPendingOnStart() {
    _ensureOpen();
    final Future<MobileCommandReplayReport>? existing = _startupReplay;
    if (existing != null) {
      return existing;
    }
    final Future<MobileCommandReplayReport> replay =
        _runOpenOperation<MobileCommandReplayReport>(
          () => _runRecoveryOperation(_replayPendingOnStart),
        );
    _startupReplay = replay;
    return replay;
  }

  bool claimStartupReplayOutcome() {
    if (_closed || _startupReplayClaimed) {
      return false;
    }
    _startupReplayClaimed = true;
    return true;
  }

  Stream<void> get changes => _changesController.stream;

  bool get isClosed => _closed;

  Future<MobileCommandRecoverySnapshot> recoverySnapshot() {
    return _runOpenOperation<MobileCommandRecoverySnapshot>(
      () => _runRecoveryOperation(_loadRecoverySnapshot),
    );
  }

  Future<bool> dismissFailed({required MobileCommandRecoveryItem item}) {
    return _runOpenOperation<bool>(
      () => _runRecoveryOperation(
        () => _stateLock.run<bool>(() async {
          final List<MobileCommand> commands = await _store.load();
          final int index = commands.indexWhere(
            (MobileCommand command) =>
                command.ownerId == ownerId && item.refersTo(command),
          );
          if (index < 0) {
            return false;
          }
          if (commands[index].state != MobileCommandState.failed) {
            throw const MobileCommandDismissalException();
          }
          final List<MobileCommand> updated = <MobileCommand>[...commands]
            ..removeAt(index);
          await _store.save(updated);
          _publishChanges();
          return true;
        }),
      ),
    );
  }

  Future<T> _runRecoveryOperation<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on MobileCommandDismissalException {
      rethrow;
    } on MobileCommandRecoveryUnavailableException {
      rethrow;
    } on Object {
      throw const MobileCommandRecoveryUnavailableException();
    }
  }

  Future<T> _runStorageOperation<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on MobileCommandRecoveryUnavailableException {
      rethrow;
    } on Object {
      throw const MobileCommandRecoveryUnavailableException();
    }
  }

  Future<MobileCommandReplayReport> _replayPending() async {
    final List<_ReplayLaneReport> laneReports =
        await Future.wait(<Future<_ReplayLaneReport>>[
          _replayOrderedStateLanes(),
          _laneLocks[MobileCommandLane.telemetry]!.run(
            () => _replayLane(MobileCommandLane.telemetry),
          ),
        ]);
    return _buildReplayReport(laneReports);
  }

  Future<MobileCommandReplayReport> _replayPendingOnStart() async {
    _startTelemetryReplay();
    final List<_ReplayLaneReport> laneReports = <_ReplayLaneReport>[
      await _replayOrderedStateLanes(),
    ];
    return _buildReplayReport(laneReports);
  }

  Future<MobileCommandReplayReport> _buildReplayReport(
    List<_ReplayLaneReport> laneReports,
  ) async {
    final int succeeded = laneReports.fold<int>(
      0,
      (int total, _ReplayLaneReport report) => total + report.succeeded,
    );
    final int retryableFailures = laneReports.fold<int>(
      0,
      (int total, _ReplayLaneReport report) => total + report.retryableFailures,
    );
    final int permanentFailures = laneReports.fold<int>(
      0,
      (int total, _ReplayLaneReport report) => total + report.permanentFailures,
    );

    final List<MobileCommand> commands = await _loadCommands();
    final int pendingAfter = commands
        .where(
          (MobileCommand command) =>
              command.ownerId == ownerId &&
              command.state == MobileCommandState.pending,
        )
        .length;
    final int failedAfter = commands
        .where(
          (MobileCommand command) =>
              command.ownerId == ownerId &&
              command.state == MobileCommandState.failed,
        )
        .length;
    return MobileCommandReplayReport(
      succeeded: succeeded,
      retryableFailures: retryableFailures,
      permanentFailures: permanentFailures,
      pendingAfter: pendingAfter,
      failedAfter: failedAfter,
    );
  }

  void _startTelemetryReplay() {
    if (_startupTelemetryReplay != null) {
      return;
    }
    final Future<void> replay = _runOpenOperation<void>(
      () => _runRecoveryOperation<void>(() async {
        await _laneLocks[MobileCommandLane.telemetry]!.run(
          () => _replayLane(MobileCommandLane.telemetry),
        );
      }),
    );
    _startupTelemetryReplay = replay;
    unawaited(
      replay.then<void>(
        (void _) {
          if (identical(_startupTelemetryReplay, replay)) {
            _startupTelemetryReplay = null;
          }
        },
        onError: (Object _, StackTrace _) {
          if (identical(_startupTelemetryReplay, replay)) {
            _startupTelemetryReplay = null;
          }
        },
      ),
    );
  }

  Future<_ReplayLaneReport> _replayOrderedStateLanes() async {
    final _ReplayLaneReport activity =
        await _laneLocks[MobileCommandLane.activity]!.run(
          () => _replayLane(MobileCommandLane.activity),
        );
    if (activity.retryableFailures > 0) {
      return activity;
    }
    final _ReplayLaneReport gameplay =
        await _laneLocks[MobileCommandLane.gameplay]!.run(
          () => _replayLane(MobileCommandLane.gameplay),
        );
    return activity.combinedWith(gameplay);
  }

  Future<void> close() {
    final Future<void>? existing = _closeFuture;
    if (existing != null) {
      return existing;
    }
    _closed = true;
    final Future<void> closing = _shutdown();
    _closeFuture = closing;
    return closing;
  }

  Future<void> _shutdown() async {
    await _waitForIdle();
    await _changesController.close();
  }

  Future<void> _waitForIdle() async {
    if (_activeOperations == 0) {
      return;
    }
    final Completer<void> completer = _idleCompleter ??= Completer<void>();
    await completer.future;
  }

  Future<T> _runOpenOperation<T>(Future<T> Function() action) {
    _ensureOpen();
    _activeOperations += 1;
    try {
      return action().whenComplete(_completeOperation);
    } on Object {
      _completeOperation();
      rethrow;
    }
  }

  void _completeOperation() {
    _activeOperations -= 1;
    if (_activeOperations < 0) {
      throw StateError('Некорректный счётчик mobile runtime operations');
    }
    if (_activeOperations == 0) {
      final Completer<void>? completer = _idleCompleter;
      _idleCompleter = null;
      if (completer != null && !completer.isCompleted) {
        completer.complete();
      }
    }
  }

  void _ensureOpen() {
    if (_closed) {
      throw StateError('Mobile command runtime уже остановлен');
    }
  }

  Future<T> _submit<T>({
    required MobileCommandType type,
    required String proposedKey,
    required String fingerprint,
    required Map<String, Object?> payload,
  }) {
    final MobileCommandLane lane = mobileCommandLaneFor(type, payload);
    final AsyncLock laneLock = _laneLocks[lane]!;
    return laneLock.run<T>(() async {
      final MobileCommand target = await _ensurePending(
        type: type,
        proposedKey: proposedKey,
        fingerprint: fingerprint,
        payload: payload,
      );
      if (target.lane != lane) {
        throw StateError('Сохранённое действие сменило очередь выполнения');
      }
      final Object result = await _drainForSubmit(target);
      return result as T;
    });
  }

  Future<MobileCommand> _ensurePending({
    required MobileCommandType type,
    required String proposedKey,
    required String fingerprint,
    required Map<String, Object?> payload,
  }) {
    final String normalizedProposedKey = _requireText(
      proposedKey,
      'idempotencyKey',
    );
    return _runStorageOperation(
      () => _stateLock.run<MobileCommand>(() async {
        final List<MobileCommand> commands = await _store.load();
        final List<MobileCommand> matching =
            commands
                .where(
                  (MobileCommand command) =>
                      command.ownerId == ownerId &&
                      command.type == type &&
                      command.fingerprint == fingerprint &&
                      command.state == MobileCommandState.pending,
                )
                .toList(growable: false)
              ..sort(_compareCommands);
        if (matching.isNotEmpty) {
          return matching.first;
        }

        String key = normalizedProposedKey;
        String commandId = '${type.wireName}:$key';
        while (commands.any(
          (MobileCommand command) => command.commandId == commandId,
        )) {
          key = _keyFactory(type, _clock().toUtc());
          commandId = '${type.wireName}:$key';
        }
        final MobileCommand command = MobileCommand.pending(
          ownerId: ownerId,
          type: type,
          idempotencyKey: key,
          fingerprint: fingerprint,
          payload: payload,
          now: _clock(),
        );
        final List<MobileCommand> updated = <MobileCommand>[
          ...commands,
          command,
        ]..sort(_compareCommands);
        await _store.save(updated);
        _publishChanges();
        return command;
      }),
    );
  }

  Future<Object> _drainForSubmit(MobileCommand target) async {
    final List<MobileCommand> pending = await _pendingForLane(target.lane);
    for (final MobileCommand command in pending) {
      try {
        final Object result = await _dispatch(command);
        await _remove(command.commandId);
        if (command.commandId == target.commandId) {
          return result;
        }
      } catch (error, stackTrace) {
        final bool terminal = _isTerminal(error);
        await _recordFailure(command, error, terminal: terminal);
        if (command.commandId == target.commandId) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        if (!terminal) {
          throw MobileCommandLaneBlockedException(lane: command.lane);
        }
      }
    }
    throw StateError('Ожидающее действие исчезло до выполнения');
  }

  Future<_ReplayLaneReport> _replayLane(MobileCommandLane lane) async {
    int succeeded = 0;
    int retryableFailures = 0;
    int permanentFailures = 0;
    final List<MobileCommand> pending = await _pendingForLane(lane);

    for (final MobileCommand command in pending) {
      try {
        await _dispatch(command);
        await _remove(command.commandId);
        succeeded += 1;
      } catch (error) {
        final bool terminal = _isTerminal(error);
        await _recordFailure(command, error, terminal: terminal);
        if (terminal) {
          permanentFailures += 1;
          continue;
        }
        retryableFailures += 1;
        break;
      }
    }
    return _ReplayLaneReport(
      succeeded: succeeded,
      retryableFailures: retryableFailures,
      permanentFailures: permanentFailures,
    );
  }

  Future<Object> _dispatch(MobileCommand command) async {
    switch (command.type) {
      case MobileCommandType.activitySync:
        final StepReading reading;
        try {
          reading = StepReading.fromJson(command.payload);
        } on Object {
          throw const MobileCommandPayloadException();
        }
        return _activitySender(
          reading: reading,
          idempotencyKey: command.idempotencyKey,
        );
      case MobileCommandType.expeditionAdvance:
        final String expeditionId = _payloadString(command, 'expeditionId');
        final int energyToSpend = _payloadInt(command, 'energyToSpend');
        return _expeditionSender(
          expeditionId: expeditionId,
          energyToSpend: energyToSpend,
          idempotencyKey: command.idempotencyKey,
        );
      case MobileCommandType.eventResolution:
        final String eventId = _payloadString(command, 'eventId');
        final String choiceId = _payloadString(command, 'choiceId');
        return _eventSender(
          eventId: eventId,
          choiceId: choiceId,
          idempotencyKey: command.idempotencyKey,
        );
      case MobileCommandType.eventResultAcknowledgement:
        final EventResultAcknowledgementSender? sender =
            _eventResultAcknowledgementSender;
        if (sender == null) {
          throw const MobileCommandPayloadException();
        }
        final String receiptId = _payloadString(command, 'receiptId');
        return sender(receiptId: receiptId);
      case MobileCommandType.crafting:
        final CraftingCommandSender? sender = _craftingSender;
        if (sender == null) {
          throw const MobileCommandPayloadException();
        }
        final String recipeId = _payloadString(command, 'recipeId');
        return sender(
          recipeId: recipeId,
          idempotencyKey: command.idempotencyKey,
        );
      case MobileCommandType.platformCommand:
        final PlatformCommandSender? sender = _platformSender;
        if (sender == null) {
          throw const MobileCommandPayloadException();
        }
        final String commandType = _payloadString(command, 'commandType');
        final Map<String, Object?> payload = _payloadMap(command, 'payload');
        return sender(
          commandType: commandType,
          payload: payload,
          idempotencyKey: command.idempotencyKey,
        );
    }
  }

  Future<List<MobileCommand>> _pendingForLane(MobileCommandLane lane) async {
    final List<MobileCommand> commands = await _loadCommands();
    return commands
        .where(
          (MobileCommand command) =>
              command.ownerId == ownerId &&
              command.lane == lane &&
              command.state == MobileCommandState.pending,
        )
        .toList(growable: false)
      ..sort(_compareCommands);
  }

  Future<List<MobileCommand>> _loadCommands() {
    return _runStorageOperation(
      () => _stateLock.run<List<MobileCommand>>(_store.load),
    );
  }

  Future<void> _remove(String commandId) {
    return _runStorageOperation(
      () => _stateLock.run<void>(() async {
        final List<MobileCommand> commands = await _store.load();
        final List<MobileCommand> updated = commands
            .where(
              (MobileCommand command) =>
                  command.ownerId != ownerId || command.commandId != commandId,
            )
            .toList(growable: false);
        await _store.save(updated);
        _publishChanges();
      }),
    );
  }

  Future<void> _recordFailure(
    MobileCommand failed,
    Object error, {
    required bool terminal,
  }) {
    return _runStorageOperation(
      () => _stateLock.run<void>(() async {
        final List<MobileCommand> commands = await _store.load();
        final int index = commands.indexWhere(
          (MobileCommand command) =>
              command.ownerId == ownerId &&
              command.commandId == failed.commandId,
        );
        if (index < 0) {
          return;
        }
        final List<MobileCommand> updated = <MobileCommand>[...commands];
        updated[index] = commands[index].withAttemptFailure(
          now: _clock(),
          error: error,
          terminal: terminal,
          category: _failureCategory(error),
        );
        await _store.save(updated);
        _publishChanges();
      }),
    );
  }

  bool _isTerminal(Object error) {
    if (error is MobileCommandPayloadException || error is ArgumentError) {
      return true;
    }
    final int? statusCode = _statusCode(error);
    if (statusCode == null) {
      return false;
    }
    return statusCode >= 400 &&
        statusCode < 500 &&
        statusCode != 408 &&
        statusCode != 429;
  }

  int? _statusCode(Object error) {
    if (error is ActivityApiException) {
      return error.statusCode;
    }
    if (error is ExpeditionApiException) {
      return error.statusCode;
    }
    if (error is EventApiException) {
      return error.statusCode;
    }
    if (error is CraftingApiException) {
      return error.statusCode;
    }
    if (error is PlatformApiException) {
      return error.statusCode;
    }
    return null;
  }

  MobileCommandFailureCategory _failureCategory(Object error) {
    if (error is MobileCommandPayloadException || error is ArgumentError) {
      return MobileCommandFailureCategory.invalidCommand;
    }
    final int? statusCode = _statusCode(error);
    if (statusCode == 429) {
      return MobileCommandFailureCategory.rateLimited;
    }
    if (statusCode == 408 || (statusCode != null && statusCode >= 500)) {
      return MobileCommandFailureCategory.serverUnavailable;
    }
    if (statusCode != null && statusCode >= 400 && statusCode < 500) {
      return MobileCommandFailureCategory.rejected;
    }
    return MobileCommandFailureCategory.connectionOrResponse;
  }

  Future<MobileCommandRecoverySnapshot> _loadRecoverySnapshot() async {
    final List<MobileCommand> commands = await _loadCommands();
    final List<MobileCommandRecoveryItem> items =
        commands
            .where((MobileCommand command) => command.ownerId == ownerId)
            .map(MobileCommandRecoveryItem.fromCommand)
            .toList(growable: false)
          ..sort(_compareRecoveryItems);
    return MobileCommandRecoverySnapshot(items);
  }

  void _publishChanges() {
    if (!_closed && !_changesController.isClosed) {
      _changesController.add(null);
    }
  }

  String _payloadString(MobileCommand command, String field) {
    final Object? value = command.payload[field];
    if (value is! String || value.trim().isEmpty) {
      throw const MobileCommandPayloadException();
    }
    return value;
  }

  int _payloadInt(MobileCommand command, String field) {
    final Object? value = command.payload[field];
    if (value is! int) {
      throw const MobileCommandPayloadException();
    }
    return value;
  }

  Map<String, Object?> _payloadMap(MobileCommand command, String field) {
    final Object? value = command.payload[field];
    if (value is! Map<Object?, Object?>) {
      throw const MobileCommandPayloadException();
    }
    return value.map<String, Object?>((Object? key, Object? item) {
      if (key is! String) {
        throw const MobileCommandPayloadException();
      }
      return MapEntry<String, Object?>(key, item);
    });
  }

  static Map<String, Object?> _canonicalMap(Map<String, Object?> value) {
    final List<String> keys = value.keys.toList(growable: false)..sort();
    return <String, Object?>{
      for (final String key in keys) key: _canonicalValue(value[key]),
    };
  }

  static Object? _canonicalValue(Object? value) {
    if (value is Map<String, Object?>) {
      return _canonicalMap(value);
    }
    if (value is Map<Object?, Object?>) {
      final Map<String, Object?> normalized = value.map<String, Object?>((
        Object? key,
        Object? item,
      ) {
        if (key is! String) {
          throw const FormatException(
            'Ключи platform payload должны быть строками',
          );
        }
        return MapEntry<String, Object?>(key, item);
      });
      return _canonicalMap(normalized);
    }
    if (value is List<Object?>) {
      return value.map<Object?>(_canonicalValue).toList(growable: false);
    }
    return value;
  }

  static int _compareCommands(MobileCommand left, MobileCommand right) {
    final int byCreatedAt = left.createdAt.compareTo(right.createdAt);
    return byCreatedAt != 0
        ? byCreatedAt
        : left.commandId.compareTo(right.commandId);
  }

  static int _compareRecoveryItems(
    MobileCommandRecoveryItem left,
    MobileCommandRecoveryItem right,
  ) {
    final int byCreatedAt = left.createdAt.compareTo(right.createdAt);
    return byCreatedAt != 0 ? byCreatedAt : left.compareStableIdentity(right);
  }

  static String _defaultKey(MobileCommandType type, DateTime now) {
    final Random random = Random.secure();
    final String randomHex = List<int>.generate(
      16,
      (int index) => random.nextInt(256),
      growable: false,
    ).map<String>((int byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return '${type.wireName.toLowerCase()}-'
        '${now.toUtc().microsecondsSinceEpoch}-$randomHex';
  }

  static String _requireText(String value, String field) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, field, 'Значение обязательно');
    }
    return normalized;
  }
}

final class MobileCommandReplayReport {
  const MobileCommandReplayReport({
    required this.succeeded,
    required this.retryableFailures,
    required this.permanentFailures,
    required this.pendingAfter,
    required this.failedAfter,
  });

  final int succeeded;
  final int retryableFailures;
  final int permanentFailures;
  final int pendingAfter;
  final int failedAfter;

  bool get changedServerState => succeeded > 0;

  bool get hasMessages =>
      succeeded > 0 ||
      retryableFailures > 0 ||
      permanentFailures > 0 ||
      failedAfter > 0;
}

final class MobileCommandLaneBlockedException implements Exception {
  const MobileCommandLaneBlockedException({required this.lane});

  final MobileCommandLane lane;

  @override
  String toString() {
    return 'Очередь ${lane.wireName} ожидает безопасной повторной отправки';
  }
}

final class MobileCommandPayloadException implements Exception {
  const MobileCommandPayloadException();

  @override
  String toString() => 'Сохранённое действие содержит некорректные данные';
}

final class _ReplayLaneReport {
  const _ReplayLaneReport({
    required this.succeeded,
    required this.retryableFailures,
    required this.permanentFailures,
  });

  final int succeeded;
  final int retryableFailures;
  final int permanentFailures;

  _ReplayLaneReport combinedWith(_ReplayLaneReport other) {
    return _ReplayLaneReport(
      succeeded: succeeded + other.succeeded,
      retryableFailures: retryableFailures + other.retryableFailures,
      permanentFailures: permanentFailures + other.permanentFailures,
    );
  }
}
