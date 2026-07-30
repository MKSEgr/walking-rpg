import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command_recovery.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command_runtime.dart';
import 'package:walking_rpg_mobile/features/activity/data/activity_api_client.dart';
import 'package:walking_rpg_mobile/features/activity/domain/activity_sync_result.dart';
import 'package:walking_rpg_mobile/features/activity/domain/step_reading.dart';
import 'package:walking_rpg_mobile/features/event/data/event_api_client.dart';
import 'package:walking_rpg_mobile/features/event/domain/event_resolution_result.dart';
import 'package:walking_rpg_mobile/features/expedition/data/expedition_api_client.dart';
import 'package:walking_rpg_mobile/features/expedition/domain/expedition_advance_result.dart';
import 'package:walking_rpg_mobile/features/platform/data/platform_api_client.dart';
import 'package:walking_rpg_mobile/features/platform/domain/platform_command_result.dart';

import 'support/in_memory_mobile_command_store.dart';
import 'support/platform_fixture.dart';

void main() {
  test('persists before send and reuses the same key after restart', () async {
    final InMemoryMobileCommandStore store = InMemoryMobileCommandStore();
    final StepReading reading = _reading(6842);
    bool persistedBeforeSend = false;
    final MobileCommandRuntime firstRuntime = _runtime(
      store: store,
      activitySender:
          ({
            required StepReading reading,
            required String idempotencyKey,
          }) async {
            persistedBeforeSend =
                store.snapshot.single.idempotencyKey == idempotencyKey;
            throw StateError('response lost after commit');
          },
    );

    await expectLater(
      firstRuntime.syncActivity(
        reading: reading,
        idempotencyKey: 'activity-original',
      ),
      throwsStateError,
    );
    expect(persistedBeforeSend, isTrue);
    expect(store.snapshot.single.state, MobileCommandState.pending);

    String? replayedKey;
    final MobileCommandRuntime restartedRuntime = _runtime(
      store: store,
      activitySender:
          ({
            required StepReading reading,
            required String idempotencyKey,
          }) async {
            replayedKey = idempotencyKey;
            return _activityResult(reading.authoritativeTotal);
          },
    );

    await restartedRuntime.syncActivity(
      reading: reading,
      idempotencyKey: 'activity-new-after-restart',
    );

    expect(replayedKey, 'activity-original');
    expect(store.snapshot, isEmpty);
  });

  test('second event replays the same key and payload after restart', () async {
    final InMemoryMobileCommandStore store = InMemoryMobileCommandStore();
    final MobileCommandRuntime firstRuntime = _runtime(
      store: store,
      eventSender:
          ({
            required String eventId,
            required String choiceId,
            required String idempotencyKey,
          }) async => throw StateError('response lost'),
    );

    await expectLater(
      firstRuntime.resolve(
        eventId: 'echo-vault-v1',
        choiceId: 'stabilize-core',
        idempotencyKey: 'second-event-original',
      ),
      throwsStateError,
    );

    String? replayedEventId;
    String? replayedChoiceId;
    String? replayedKey;
    final MobileCommandRuntime restartedRuntime = _runtime(
      store: store,
      eventSender:
          ({
            required String eventId,
            required String choiceId,
            required String idempotencyKey,
          }) async {
            replayedEventId = eventId;
            replayedChoiceId = choiceId;
            replayedKey = idempotencyKey;
            return _eventResult();
          },
    );

    final MobileCommandReplayReport report = await restartedRuntime
        .replayPending();

    expect(report.succeeded, 1);
    expect(replayedEventId, 'echo-vault-v1');
    expect(replayedChoiceId, 'stabilize-core');
    expect(replayedKey, 'second-event-original');
    expect(store.snapshot, isEmpty);
  });

  test(
    'event result acknowledgement persists and replays the same receipt',
    () async {
      final InMemoryMobileCommandStore store = InMemoryMobileCommandStore();
      bool persistedBeforeSend = false;
      final MobileCommandRuntime firstRuntime = _runtime(
        store: store,
        eventResultAcknowledgementSender: ({required String receiptId}) async {
          final MobileCommand command = store.snapshot.single;
          persistedBeforeSend =
              command.type == MobileCommandType.eventResultAcknowledgement &&
              command.payload['receiptId'] == receiptId &&
              command.idempotencyKey == 'ack-original';
          throw StateError('response lost after acknowledgement');
        },
      );

      await expectLater(
        firstRuntime.acknowledgeEventResult(
          receiptId: '22222222-2222-2222-2222-222222222222',
          idempotencyKey: 'ack-original',
        ),
        throwsStateError,
      );

      expect(persistedBeforeSend, isTrue);
      expect(store.snapshot.single.lane, MobileCommandLane.gameplay);
      expect(store.snapshot.single.state, MobileCommandState.pending);

      String? replayedReceiptId;
      String? replayedKey;
      final MobileCommandRuntime restartedRuntime = _runtime(
        store: store,
        eventResultAcknowledgementSender: ({required String receiptId}) async {
          replayedReceiptId = receiptId;
          replayedKey = store.snapshot.single.idempotencyKey;
          return _acknowledgementResult(receiptId);
        },
      );

      final MobileCommandReplayReport report = await restartedRuntime
          .replayPending();

      expect(report.succeeded, 1);
      expect(replayedReceiptId, '22222222-2222-2222-2222-222222222222');
      expect(replayedKey, 'ack-original');
      expect(store.snapshot, isEmpty);
    },
  );

  test('retryable activity submit releases the gameplay lane', () async {
    final InMemoryMobileCommandStore store = InMemoryMobileCommandStore();
    int advanceCalls = 0;
    final MobileCommandRuntime runtime = _runtime(
      store: store,
      activitySender:
          ({
            required StepReading reading,
            required String idempotencyKey,
          }) async => throw StateError('offline'),
      expeditionSender:
          ({
            required String expeditionId,
            required int energyToSpend,
            required String idempotencyKey,
          }) async {
            advanceCalls += 1;
            return _advanceResult();
          },
    );

    await expectLater(
      runtime.syncActivity(
        reading: _reading(100),
        idempotencyKey: 'activity-1',
      ),
      throwsStateError,
    );
    await runtime.advance(
      expeditionId: 'starter-expedition-v1',
      energyToSpend: 30,
      idempotencyKey: 'advance-1',
    );

    expect(advanceCalls, 1);
    expect(store.snapshot.single.type, MobileCommandType.activitySync);
  });

  test('terminal 4xx does not block the next gameplay command', () async {
    final InMemoryMobileCommandStore store = InMemoryMobileCommandStore(
      <MobileCommand>[
        MobileCommand.pending(
          ownerId: 'user-1',
          type: MobileCommandType.expeditionAdvance,
          idempotencyKey: 'advance-invalid',
          fingerprint: 'advance-invalid-fingerprint',
          payload: <String, Object?>{
            'expeditionId': 'starter-expedition-v1',
            'energyToSpend': 30,
          },
          now: DateTime.utc(2026, 7, 26, 9),
        ),
        MobileCommand.pending(
          ownerId: 'user-1',
          type: MobileCommandType.eventResolution,
          idempotencyKey: 'event-valid',
          fingerprint: 'event-valid-fingerprint',
          payload: <String, Object?>{
            'eventId': 'signal-source-v1',
            'choiceId': 'trust-spark',
          },
          now: DateTime.utc(2026, 7, 26, 9, 1),
        ),
      ],
    );
    int eventCalls = 0;
    final MobileCommandRuntime runtime = _runtime(
      store: store,
      expeditionSender:
          ({
            required String expeditionId,
            required int energyToSpend,
            required String idempotencyKey,
          }) async => throw const ExpeditionApiException(
            statusCode: 400,
            code: 'VALIDATION_ERROR',
            message: 'invalid command',
          ),
      eventSender:
          ({
            required String eventId,
            required String choiceId,
            required String idempotencyKey,
          }) async {
            eventCalls += 1;
            return _eventResult();
          },
    );

    final MobileCommandReplayReport report = await runtime.replayPending();

    expect(report.succeeded, 1);
    expect(report.permanentFailures, 1);
    expect(report.failedAfter, 1);
    expect(report.hasMessages, isTrue);
    expect(eventCalls, 1);
    expect(store.snapshot.single.state, MobileCommandState.failed);
  });

  test('unknown acknowledgement receipt does not block gameplay', () async {
    final InMemoryMobileCommandStore store = InMemoryMobileCommandStore(
      <MobileCommand>[
        MobileCommand.pending(
          ownerId: 'user-1',
          type: MobileCommandType.eventResultAcknowledgement,
          idempotencyKey: 'ack-unknown',
          fingerprint: 'ack-unknown-fingerprint',
          payload: <String, Object?>{
            'receiptId': '22222222-2222-2222-2222-222222222222',
          },
          now: DateTime.utc(2026, 7, 26, 9),
        ),
        MobileCommand.pending(
          ownerId: 'user-1',
          type: MobileCommandType.eventResolution,
          idempotencyKey: 'event-after-ack',
          fingerprint: 'event-after-ack-fingerprint',
          payload: <String, Object?>{
            'eventId': 'signal-source-v1',
            'choiceId': 'trust-spark',
          },
          now: DateTime.utc(2026, 7, 26, 9, 1),
        ),
      ],
    );
    int eventCalls = 0;
    final MobileCommandRuntime runtime = _runtime(
      store: store,
      eventResultAcknowledgementSender: ({required String receiptId}) async =>
          throw const EventApiException(
            statusCode: 404,
            code: 'EVENT_RESULT_NOT_FOUND',
            message: 'receipt is unknown or belongs to another user',
          ),
      eventSender:
          ({
            required String eventId,
            required String choiceId,
            required String idempotencyKey,
          }) async {
            eventCalls += 1;
            return _eventResult();
          },
    );

    final MobileCommandReplayReport report = await runtime.replayPending();

    expect(report.permanentFailures, 1);
    expect(report.succeeded, 1);
    expect(eventCalls, 1);
    expect(
      store.snapshot.single.type,
      MobileCommandType.eventResultAcknowledgement,
    );
    expect(store.snapshot.single.state, MobileCommandState.failed);
  });

  test('429 remains pending for a later replay', () async {
    final InMemoryMobileCommandStore store = InMemoryMobileCommandStore();
    final MobileCommandRuntime runtime = _runtime(
      store: store,
      activitySender:
          ({
            required StepReading reading,
            required String idempotencyKey,
          }) async => throw const ActivityApiException(
            statusCode: 429,
            code: 'RATE_LIMITED',
            message: 'retry later',
          ),
    );

    await expectLater(
      runtime.syncActivity(
        reading: _reading(200),
        idempotencyKey: 'activity-rate-limited',
      ),
      throwsA(isA<ActivityApiException>()),
    );

    expect(store.snapshot.single.state, MobileCommandState.pending);
    expect(store.snapshot.single.attemptCount, 1);
  });

  test('commands from another owner are ignored', () async {
    final InMemoryMobileCommandStore store =
        InMemoryMobileCommandStore(<MobileCommand>[
          MobileCommand.pending(
            ownerId: 'another-user',
            type: MobileCommandType.activitySync,
            idempotencyKey: 'foreign-activity',
            fingerprint: 'foreign-fingerprint',
            payload: _reading(300).toJson(),
            now: DateTime.utc(2026, 7, 26, 9),
          ),
        ]);
    int calls = 0;
    final MobileCommandRuntime runtime = _runtime(
      store: store,
      activitySender:
          ({
            required StepReading reading,
            required String idempotencyKey,
          }) async {
            calls += 1;
            return _activityResult(reading.authoritativeTotal);
          },
    );

    final MobileCommandReplayReport report = await runtime.replayPending();

    expect(calls, 0);
    expect(report.succeeded, 0);
    expect(report.pendingAfter, 0);
    expect(store.snapshot, hasLength(1));
  });

  test(
    'platform command persists and replays the same key and payload',
    () async {
      final InMemoryMobileCommandStore store = InMemoryMobileCommandStore();
      final MobileCommandRuntime firstRuntime = _runtime(
        store: store,
        platformSender:
            ({
              required String commandType,
              required Map<String, Object?> payload,
              required String idempotencyKey,
            }) async => throw StateError('response lost'),
      );

      await expectLater(
        firstRuntime.executePlatform(
          commandType: 'advance_weekly_route',
          payload: <String, Object?>{
            'metadata': <String, Object?>{'z': 2, 'a': 1},
            'energyToSpend': 10,
          },
          idempotencyKey: 'weekly-original',
        ),
        throwsStateError,
      );

      String? replayedType;
      Map<String, Object?>? replayedPayload;
      String? replayedKey;
      final MobileCommandRuntime restarted = _runtime(
        store: store,
        platformSender:
            ({
              required String commandType,
              required Map<String, Object?> payload,
              required String idempotencyKey,
            }) async {
              replayedType = commandType;
              replayedPayload = payload;
              replayedKey = idempotencyKey;
              return _platformResult(commandType, idempotencyKey);
            },
      );

      final MobileCommandReplayReport report = await restarted.replayPending();

      expect(report.succeeded, 1);
      expect(replayedType, 'ADVANCE_WEEKLY_ROUTE');
      expect(replayedPayload, <String, Object?>{
        'energyToSpend': 10,
        'metadata': <String, Object?>{'a': 1, 'z': 2},
      });
      expect(replayedKey, 'weekly-original');
      expect(store.snapshot, isEmpty);
    },
  );

  test('platform fingerprint ignores map key order', () async {
    final InMemoryMobileCommandStore store = InMemoryMobileCommandStore();
    final MobileCommandRuntime offline = _runtime(
      store: store,
      platformSender:
          ({
            required String commandType,
            required Map<String, Object?> payload,
            required String idempotencyKey,
          }) async => throw StateError('offline'),
    );

    await expectLater(
      offline.executePlatform(
        commandType: 'TEST_COMMAND',
        payload: <String, Object?>{
          'outer': <String, Object?>{'b': 2, 'a': 1},
          'value': 3,
        },
        idempotencyKey: 'first-key',
      ),
      throwsStateError,
    );

    String? sentKey;
    final MobileCommandRuntime online = _runtime(
      store: store,
      platformSender:
          ({
            required String commandType,
            required Map<String, Object?> payload,
            required String idempotencyKey,
          }) async {
            sentKey = idempotencyKey;
            return _platformResult(commandType, idempotencyKey);
          },
    );

    await online.executePlatform(
      commandType: 'test_command',
      payload: <String, Object?>{
        'value': 3,
        'outer': <String, Object?>{'a': 1, 'b': 2},
      },
      idempotencyKey: 'second-key',
    );

    expect(sentKey, 'first-key');
    expect(store.snapshot, isEmpty);
  });

  test(
    'terminal platform conflict does not block later gameplay command',
    () async {
      final InMemoryMobileCommandStore store = InMemoryMobileCommandStore(
        <MobileCommand>[
          MobileCommand.pending(
            ownerId: 'user-1',
            type: MobileCommandType.platformCommand,
            idempotencyKey: 'platform-conflict',
            fingerprint: 'platform-conflict-fingerprint',
            payload: <String, Object?>{
              'commandType': 'UNLOCK_SKILL',
              'payload': <String, Object?>{'skillId': 'trail-memory'},
            },
            now: DateTime.utc(2026, 7, 26, 9),
          ),
          MobileCommand.pending(
            ownerId: 'user-1',
            type: MobileCommandType.eventResolution,
            idempotencyKey: 'event-after-platform',
            fingerprint: 'event-after-platform-fingerprint',
            payload: <String, Object?>{
              'eventId': 'signal-source-v1',
              'choiceId': 'trust-spark',
            },
            now: DateTime.utc(2026, 7, 26, 9, 1),
          ),
        ],
      );
      int eventCalls = 0;
      final MobileCommandRuntime runtime = _runtime(
        store: store,
        platformSender:
            ({
              required String commandType,
              required Map<String, Object?> payload,
              required String idempotencyKey,
            }) async => throw const PlatformApiException(
              statusCode: 409,
              code: 'PLATFORM_STATE_CONFLICT',
              message: 'state conflict',
            ),
        eventSender:
            ({
              required String eventId,
              required String choiceId,
              required String idempotencyKey,
            }) async {
              eventCalls += 1;
              return _eventResult();
            },
      );

      final MobileCommandReplayReport report = await runtime.replayPending();

      expect(report.permanentFailures, 1);
      expect(report.succeeded, 1);
      expect(eventCalls, 1);
      expect(store.snapshot.single.type, MobileCommandType.platformCommand);
      expect(store.snapshot.single.state, MobileCommandState.failed);
    },
  );

  test('recovery snapshot is owner scoped and presentation safe', () async {
    final MobileCommand ownPending = MobileCommand.pending(
      ownerId: 'user-1',
      type: MobileCommandType.eventResultAcknowledgement,
      idempotencyKey: 'private-ack-key',
      fingerprint: 'private-fingerprint',
      payload: <String, Object?>{'receiptId': 'private-receipt'},
      now: DateTime.utc(2026, 7, 26, 9),
    );
    final MobileCommand ownFailed =
        MobileCommand.pending(
          ownerId: 'user-1',
          type: MobileCommandType.expeditionAdvance,
          idempotencyKey: 'private-advance-key',
          fingerprint: 'private-advance-fingerprint',
          payload: <String, Object?>{
            'expeditionId': 'private-expedition',
            'energyToSpend': 30,
          },
          now: DateTime.utc(2026, 7, 26, 9, 1),
        ).withAttemptFailure(
          now: DateTime.utc(2026, 7, 26, 9, 2),
          error: const ExpeditionApiException(
            statusCode: 409,
            code: 'STATE_CONFLICT',
            message: 'private backend detail',
          ),
          terminal: true,
          category: MobileCommandFailureCategory.rejected,
        );
    final MobileCommand foreign = MobileCommand.pending(
      ownerId: 'another-user',
      type: MobileCommandType.activitySync,
      idempotencyKey: 'foreign-key',
      fingerprint: 'foreign-fingerprint',
      payload: _reading(500).toJson(),
      now: DateTime.utc(2026, 7, 26, 9, 3),
    );
    final MobileCommandRuntime runtime = _runtime(
      store: InMemoryMobileCommandStore(<MobileCommand>[
        ownFailed,
        foreign,
        ownPending,
      ]),
    );

    final MobileCommandRecoverySnapshot snapshot = await runtime
        .recoverySnapshot();

    expect(snapshot.totalCount, 2);
    expect(snapshot.pendingCount, 1);
    expect(snapshot.failedCount, 1);
    expect(
      snapshot.items.map((MobileCommandRecoveryItem item) => item.type),
      <MobileCommandType>[
        MobileCommandType.eventResultAcknowledgement,
        MobileCommandType.expeditionAdvance,
      ],
    );
    expect(
      snapshot.items.last.failureCategory,
      MobileCommandFailureCategory.rejected,
    );
  });

  test('dismisses only current-owner terminal records', () async {
    MobileCommand failed(String ownerId, String key) =>
        MobileCommand.pending(
          ownerId: ownerId,
          type: MobileCommandType.eventResolution,
          idempotencyKey: key,
          fingerprint: 'fingerprint-$key',
          payload: <String, Object?>{
            'eventId': 'signal-source-v1',
            'choiceId': 'trust-spark',
          },
          now: DateTime.utc(2026, 7, 26, 9),
        ).withAttemptFailure(
          now: DateTime.utc(2026, 7, 26, 9, 1),
          error: StateError('terminal'),
          terminal: true,
          category: MobileCommandFailureCategory.invalidCommand,
        );

    final MobileCommand own = failed('user-1', 'own-failed');
    final MobileCommand foreign = failed('another-user', 'foreign-failed');
    final InMemoryMobileCommandStore store = InMemoryMobileCommandStore(
      <MobileCommand>[own, foreign],
    );
    final MobileCommandRuntime runtime = _runtime(store: store);

    expect(
      await runtime.dismissFailed(
        item: MobileCommandRecoveryItem.fromCommand(foreign),
      ),
      isFalse,
    );
    final MobileCommandRecoveryItem ownItem =
        (await runtime.recoverySnapshot()).items.single;
    expect(await runtime.dismissFailed(item: ownItem), isTrue);
    expect(store.snapshot, <MobileCommand>[foreign]);
    expect(await runtime.dismissFailed(item: ownItem), isFalse);
  });

  test('never dismisses an ambiguous pending command', () async {
    final MobileCommand pending = MobileCommand.pending(
      ownerId: 'user-1',
      type: MobileCommandType.expeditionAdvance,
      idempotencyKey: 'pending-advance',
      fingerprint: 'pending-fingerprint',
      payload: <String, Object?>{
        'expeditionId': 'starter-expedition-v1',
        'energyToSpend': 30,
      },
      now: DateTime.utc(2026, 7, 26, 9),
    );
    final InMemoryMobileCommandStore store = InMemoryMobileCommandStore(
      <MobileCommand>[pending],
    );
    final MobileCommandRuntime runtime = _runtime(store: store);
    final MobileCommandRecoveryItem item =
        (await runtime.recoverySnapshot()).items.single;

    await expectLater(
      runtime.dismissFailed(item: item),
      throwsA(isA<MobileCommandDismissalException>()),
    );
    expect(store.snapshot, <MobileCommand>[pending]);
  });

  test('stale recovery item cannot dismiss a replacement record', () async {
    MobileCommand failedAt(DateTime createdAt, DateTime failedAt) =>
        MobileCommand.pending(
          ownerId: 'user-1',
          type: MobileCommandType.eventResolution,
          idempotencyKey: 'reused-key',
          fingerprint: 'reused-fingerprint',
          payload: <String, Object?>{
            'eventId': 'signal-source-v1',
            'choiceId': 'trust-spark',
          },
          now: createdAt,
        ).withAttemptFailure(
          now: failedAt,
          error: StateError('terminal'),
          terminal: true,
          category: MobileCommandFailureCategory.rejected,
        );
    final MobileCommand first = failedAt(
      DateTime.utc(2026, 7, 26, 9),
      DateTime.utc(2026, 7, 26, 9, 1),
    );
    final InMemoryMobileCommandStore store = InMemoryMobileCommandStore(
      <MobileCommand>[first],
    );
    final MobileCommandRuntime runtime = _runtime(store: store);
    final MobileCommandRecoveryItem staleItem =
        (await runtime.recoverySnapshot()).items.single;
    final MobileCommand replacement = failedAt(
      DateTime.utc(2026, 7, 26, 10),
      DateTime.utc(2026, 7, 26, 10, 1),
    );
    await store.save(<MobileCommand>[replacement]);

    expect(await runtime.dismissFailed(item: staleItem), isFalse);
    expect(store.snapshot, <MobileCommand>[replacement]);
  });

  test('experiment exposure cannot block gameplay recovery', () async {
    final MobileCommand exposure = MobileCommand.pending(
      ownerId: 'user-1',
      type: MobileCommandType.platformCommand,
      idempotencyKey: 'exposure-key',
      fingerprint: 'exposure-fingerprint',
      payload: <String, Object?>{
        'commandType': 'RECORD_EXPERIMENT_EXPOSURE',
        'payload': <String, Object?>{
          'experimentId': 'first-journey-copy',
          'variant': 'b',
        },
      },
      now: DateTime.utc(2026, 7, 26, 9),
    );
    final MobileCommand event = MobileCommand.pending(
      ownerId: 'user-1',
      type: MobileCommandType.eventResolution,
      idempotencyKey: 'event-key',
      fingerprint: 'event-fingerprint',
      payload: <String, Object?>{
        'eventId': 'signal-source-v1',
        'choiceId': 'trust-spark',
      },
      now: DateTime.utc(2026, 7, 26, 9, 1),
    );
    final InMemoryMobileCommandStore store = InMemoryMobileCommandStore(
      <MobileCommand>[exposure, event],
    );
    int eventCalls = 0;
    final MobileCommandRuntime runtime = _runtime(
      store: store,
      platformSender:
          ({
            required String commandType,
            required Map<String, Object?> payload,
            required String idempotencyKey,
          }) async => throw StateError('telemetry offline'),
      eventSender:
          ({
            required String eventId,
            required String choiceId,
            required String idempotencyKey,
          }) async {
            eventCalls += 1;
            return _eventResult();
          },
    );

    final MobileCommandReplayReport report = await runtime.replayPending();
    await runtime.close();

    expect(exposure.lane, MobileCommandLane.telemetry);
    expect(report.retryableFailures, 1);
    expect(report.succeeded, 1);
    expect(eventCalls, 1);
    expect(store.snapshot.single.commandId, exposure.commandId);
    expect(store.snapshot.single.state, MobileCommandState.pending);
  });

  test(
    'replay preserves activity before gameplay while telemetry runs aside',
    () async {
      final MobileCommand activity = MobileCommand.pending(
        ownerId: 'user-1',
        type: MobileCommandType.activitySync,
        idempotencyKey: 'activity-key',
        fingerprint: 'activity-fingerprint',
        payload: _reading(6842).toJson(),
        now: DateTime.utc(2026, 7, 26, 9),
      );
      final MobileCommand event = MobileCommand.pending(
        ownerId: 'user-1',
        type: MobileCommandType.eventResolution,
        idempotencyKey: 'event-key',
        fingerprint: 'event-fingerprint',
        payload: <String, Object?>{
          'eventId': 'signal-source-v1',
          'choiceId': 'trust-spark',
        },
        now: DateTime.utc(2026, 7, 26, 9, 1),
      );
      final MobileCommand exposure = MobileCommand.pending(
        ownerId: 'user-1',
        type: MobileCommandType.platformCommand,
        idempotencyKey: 'exposure-key',
        fingerprint: 'exposure-fingerprint',
        payload: <String, Object?>{
          'commandType': 'RECORD_EXPERIMENT_EXPOSURE',
          'payload': <String, Object?>{
            'experimentId': 'first-journey-copy',
            'variant': 'b',
          },
        },
        now: DateTime.utc(2026, 7, 26, 9, 2),
      );
      final InMemoryMobileCommandStore store = InMemoryMobileCommandStore(
        <MobileCommand>[activity, event, exposure],
      );
      final Completer<void> activityStarted = Completer<void>();
      final Completer<void> releaseActivity = Completer<void>();
      final Completer<void> telemetryStarted = Completer<void>();
      final Completer<void> releaseTelemetry = Completer<void>();
      final Completer<void> gameplayStarted = Completer<void>();
      int gameplayCalls = 0;
      final MobileCommandRuntime runtime = _runtime(
        store: store,
        activitySender:
            ({
              required StepReading reading,
              required String idempotencyKey,
            }) async {
              activityStarted.complete();
              await releaseActivity.future;
              return _activityResult(reading.authoritativeTotal);
            },
        eventSender:
            ({
              required String eventId,
              required String choiceId,
              required String idempotencyKey,
            }) async {
              gameplayCalls += 1;
              gameplayStarted.complete();
              return _eventResult();
            },
        platformSender:
            ({
              required String commandType,
              required Map<String, Object?> payload,
              required String idempotencyKey,
            }) async {
              telemetryStarted.complete();
              await releaseTelemetry.future;
              throw StateError('telemetry offline');
            },
      );

      final Future<MobileCommandReplayReport> replay = runtime
          .replayPendingOnStart();
      await Future.wait(<Future<void>>[
        activityStarted.future,
        telemetryStarted.future,
      ]);
      await Future<void>.delayed(Duration.zero);
      expect(gameplayCalls, 0);

      releaseActivity.complete();
      await gameplayStarted.future;
      expect(gameplayCalls, 1);
      expect(releaseTelemetry.isCompleted, isFalse);

      final MobileCommandReplayReport report = await replay;
      expect(report.succeeded, 2);
      expect(report.retryableFailures, 0);
      expect(report.pendingAfter, 1);
      expect(releaseTelemetry.isCompleted, isFalse);

      releaseTelemetry.complete();
      await runtime.close();
      expect(store.snapshot.single.lane, MobileCommandLane.telemetry);
    },
  );

  test(
    'startup replay is memoized per runtime and resets after restart',
    () async {
      final MobileCommand activity = MobileCommand.pending(
        ownerId: 'user-1',
        type: MobileCommandType.activitySync,
        idempotencyKey: 'startup-activity',
        fingerprint: 'startup-activity-fingerprint',
        payload: _reading(6842).toJson(),
        now: DateTime.utc(2026, 7, 26, 9),
      );
      final InMemoryMobileCommandStore store = InMemoryMobileCommandStore(
        <MobileCommand>[activity],
      );
      int activityCalls = 0;

      final ActivityCommandSender offlineSender =
          ({
            required StepReading reading,
            required String idempotencyKey,
          }) async {
            activityCalls += 1;
            throw StateError('activity offline');
          };

      final MobileCommandRuntime firstRuntime = _runtime(
        store: store,
        activitySender: offlineSender,
      );
      final Future<MobileCommandReplayReport> firstReplay = firstRuntime
          .replayPendingOnStart();
      final Future<MobileCommandReplayReport> concurrentReplay = firstRuntime
          .replayPendingOnStart();

      expect(identical(firstReplay, concurrentReplay), isTrue);
      final MobileCommandReplayReport firstReport = await firstReplay;
      final MobileCommandReplayReport concurrentReport = await concurrentReplay;
      final Future<MobileCommandReplayReport> completedReplay = firstRuntime
          .replayPendingOnStart();

      expect(identical(firstReplay, completedReplay), isTrue);
      expect(await completedReplay, same(firstReport));
      expect(concurrentReport, same(firstReport));
      expect(activityCalls, 1);
      expect(firstReport.retryableFailures, 1);
      expect(store.snapshot.single.attemptCount, 1);
      await firstRuntime.close();

      final MobileCommandRuntime restartedRuntime = _runtime(
        store: store,
        activitySender: offlineSender,
      );
      final MobileCommandReplayReport restartedReport = await restartedRuntime
          .replayPendingOnStart();

      expect(activityCalls, 2);
      expect(restartedReport.retryableFailures, 1);
      expect(store.snapshot.single.attemptCount, 2);
      await restartedRuntime.close();
    },
  );

  test('retryable activity replay keeps dependent gameplay pending', () async {
    final MobileCommand activity = MobileCommand.pending(
      ownerId: 'user-1',
      type: MobileCommandType.activitySync,
      idempotencyKey: 'activity-key',
      fingerprint: 'activity-fingerprint',
      payload: _reading(6842).toJson(),
      now: DateTime.utc(2026, 7, 26, 9),
    );
    final MobileCommand event = MobileCommand.pending(
      ownerId: 'user-1',
      type: MobileCommandType.eventResolution,
      idempotencyKey: 'event-key',
      fingerprint: 'event-fingerprint',
      payload: <String, Object?>{
        'eventId': 'signal-source-v1',
        'choiceId': 'trust-spark',
      },
      now: DateTime.utc(2026, 7, 26, 9, 1),
    );
    final InMemoryMobileCommandStore store = InMemoryMobileCommandStore(
      <MobileCommand>[activity, event],
    );
    int gameplayCalls = 0;
    final MobileCommandRuntime runtime = _runtime(
      store: store,
      activitySender:
          ({
            required StepReading reading,
            required String idempotencyKey,
          }) async => throw StateError('activity offline'),
      eventSender:
          ({
            required String eventId,
            required String choiceId,
            required String idempotencyKey,
          }) async {
            gameplayCalls += 1;
            return _eventResult();
          },
    );

    final MobileCommandReplayReport report = await runtime.replayPending();

    expect(gameplayCalls, 0);
    expect(report.succeeded, 0);
    expect(report.retryableFailures, 1);
    expect(report.pendingAfter, 2);
    expect(store.snapshot, hasLength(2));
    expect(store.snapshot[0].attemptCount, 1);
    expect(store.snapshot[1].attemptCount, 0);
    expect(
      store.snapshot.map((MobileCommand command) => command.state),
      everyElement(MobileCommandState.pending),
    );
  });

  test('in-flight experiment exposure does not hold gameplay lock', () async {
    final InMemoryMobileCommandStore store = InMemoryMobileCommandStore();
    final Completer<void> exposureStarted = Completer<void>();
    final Completer<void> releaseExposure = Completer<void>();
    int eventCalls = 0;
    final MobileCommandRuntime runtime = _runtime(
      store: store,
      platformSender:
          ({
            required String commandType,
            required Map<String, Object?> payload,
            required String idempotencyKey,
          }) async {
            exposureStarted.complete();
            await releaseExposure.future;
            throw StateError('telemetry offline');
          },
      eventSender:
          ({
            required String eventId,
            required String choiceId,
            required String idempotencyKey,
          }) async {
            eventCalls += 1;
            return _eventResult();
          },
    );

    final Future<PlatformCommandResult> exposure = runtime.executePlatform(
      commandType: 'RECORD_EXPERIMENT_EXPOSURE',
      payload: <String, Object?>{
        'experimentId': 'first-journey-copy',
        'variant': 'b',
      },
      idempotencyKey: 'exposure-key',
    );
    await exposureStarted.future;

    await runtime.resolve(
      eventId: 'signal-source-v1',
      choiceId: 'trust-spark',
      idempotencyKey: 'event-key',
    );
    expect(eventCalls, 1);

    releaseExposure.complete();
    await expectLater(exposure, throwsStateError);
    expect(store.snapshot.single.lane, MobileCommandLane.telemetry);
  });
}

MobileCommandRuntime _runtime({
  required InMemoryMobileCommandStore store,
  ActivityCommandSender? activitySender,
  ExpeditionCommandSender? expeditionSender,
  EventCommandSender? eventSender,
  EventResultAcknowledgementSender? eventResultAcknowledgementSender,
  PlatformCommandSender? platformSender,
}) {
  return MobileCommandRuntime(
    ownerId: 'user-1',
    store: store,
    activitySender:
        activitySender ??
        ({
          required StepReading reading,
          required String idempotencyKey,
        }) async => _activityResult(reading.authoritativeTotal),
    expeditionSender:
        expeditionSender ??
        ({
          required String expeditionId,
          required int energyToSpend,
          required String idempotencyKey,
        }) async => _advanceResult(),
    eventSender:
        eventSender ??
        ({
          required String eventId,
          required String choiceId,
          required String idempotencyKey,
        }) async => _eventResult(),
    eventResultAcknowledgementSender:
        eventResultAcknowledgementSender ??
        ({required String receiptId}) async =>
            _acknowledgementResult(receiptId),
    platformSender:
        platformSender ??
        ({
          required String commandType,
          required Map<String, Object?> payload,
          required String idempotencyKey,
        }) async => _platformResult(commandType, idempotencyKey),
    clock: () => DateTime.utc(2026, 7, 26, 10),
  );
}

StepReading _reading(int total) {
  return StepReading(
    authoritativeTotal: total,
    localDate: DateTime(2026, 7, 26),
    timeZone: 'Europe/Berlin',
    syncCursor: 'health:2026-07-26:$total',
  );
}

ActivitySyncResult _activityResult(int total) {
  return ActivitySyncResult(
    acceptedTotal: total,
    acceptedDelta: total,
    energyGranted: total ~/ 100,
    energyBalanceAfter: total ~/ 100,
    economyVersion: 1,
    riskStatus: 'ACCEPTED',
    stateVersion: 1,
    serverTime: '2026-07-26T10:00:00Z',
  );
}

ExpeditionAdvanceResult _advanceResult() {
  return const ExpeditionAdvanceResult(
    contentVersion: 'chapter-1-v1',
    expeditionId: 'starter-expedition-v1',
    expeditionName: 'Сигнал из туманного сектора',
    energySpent: 30,
    energyBalanceAfter: 0,
    economyVersion: 2,
    progressAfter: 30,
    requiredEnergy: 30,
    expeditionVersion: 1,
    status: 'EVENT_READY',
    currentNodeId: 'outer-beacon',
    currentNodeName: 'Внешний маяк',
    unlockedEvent: null,
    serverTime: '2026-07-26T10:00:00Z',
  );
}

EventResolutionResult _eventResult() {
  return const EventResolutionResult(
    receiptId: '11111111-1111-1111-1111-111111111111',
    handoffRequired: true,
    contentVersion: 'chapter-1-v1',
    expeditionId: 'starter-expedition-v1',
    expeditionStatus: 'IN_PROGRESS',
    expeditionVersion: 2,
    eventId: 'signal-source-v1',
    eventTitle: 'Источник сигнала',
    status: 'RESOLVED',
    choiceId: 'trust-spark',
    choiceTitle: 'Довериться Искре',
    outcomeTitle: 'Новый маршрут',
    outcomeSummary: 'Искра находит безопасный путь.',
    pilot: EventPilotReward(
      pilotId: 'navigator-v1',
      name: 'Навигатор',
      level: 1,
      experienceGained: 10,
      currentExperience: 30,
      nextLevelExperience: 100,
      version: 1,
    ),
    pet: EventPetReward(
      petId: 'spark-v1',
      name: 'Искра',
      level: 1,
      bondGained: 5,
      bond: 15,
      version: 1,
    ),
    nextNode: EventNextNode(nodeId: 'lumen-gate', name: 'Люминовые ворота'),
    serverTime: '2026-07-26T10:00:00Z',
  );
}

EventResultAcknowledgement _acknowledgementResult(String receiptId) {
  return EventResultAcknowledgement(
    receiptId: receiptId,
    eventId: 'signal-source-v1',
    status: 'ACKNOWLEDGED',
    acknowledgedAt: '2026-07-26T10:00:01Z',
    serverTime: '2026-07-26T10:00:01Z',
  );
}

PlatformCommandResult _platformResult(
  String commandType,
  String idempotencyKey,
) {
  return platformCommandResult(
    commandType: commandType,
    idempotencyKey: idempotencyKey,
    snapshot: platformSnapshot(),
  );
}
