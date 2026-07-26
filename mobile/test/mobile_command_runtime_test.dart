import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command_runtime.dart';
import 'package:walking_rpg_mobile/features/activity/data/activity_api_client.dart';
import 'package:walking_rpg_mobile/features/activity/domain/activity_sync_result.dart';
import 'package:walking_rpg_mobile/features/activity/domain/step_reading.dart';
import 'package:walking_rpg_mobile/features/event/domain/event_resolution_result.dart';
import 'package:walking_rpg_mobile/features/expedition/data/expedition_api_client.dart';
import 'package:walking_rpg_mobile/features/expedition/domain/expedition_advance_result.dart';

import 'support/in_memory_mobile_command_store.dart';

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

    final MobileCommandReplayReport report =
        await restartedRuntime.replayPending();

    expect(report.succeeded, 1);
    expect(replayedEventId, 'echo-vault-v1');
    expect(replayedChoiceId, 'stabilize-core');
    expect(replayedKey, 'second-event-original');
    expect(store.snapshot, isEmpty);
  });

  test('retryable activity failure does not block gameplay lane', () async {
    final InMemoryMobileCommandStore store = InMemoryMobileCommandStore(
      <MobileCommand>[
        MobileCommand.pending(
          ownerId: 'user-1',
          type: MobileCommandType.activitySync,
          idempotencyKey: 'activity-1',
          fingerprint: 'activity-fingerprint',
          payload: _reading(100).toJson(),
          now: DateTime.utc(2026, 7, 26, 9),
        ),
        MobileCommand.pending(
          ownerId: 'user-1',
          type: MobileCommandType.expeditionAdvance,
          idempotencyKey: 'advance-1',
          fingerprint: 'advance-fingerprint',
          payload: <String, Object?>{
            'expeditionId': 'starter-expedition-v1',
            'energyToSpend': 30,
          },
          now: DateTime.utc(2026, 7, 26, 9, 1),
        ),
      ],
    );
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

    final MobileCommandReplayReport report = await runtime.replayPending();

    expect(report.succeeded, 1);
    expect(report.retryableFailures, 1);
    expect(report.pendingAfter, 1);
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
    expect(eventCalls, 1);
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
}

MobileCommandRuntime _runtime({
  required InMemoryMobileCommandStore store,
  ActivityCommandSender? activitySender,
  ExpeditionCommandSender? expeditionSender,
  EventCommandSender? eventSender,
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
    contentVersion: 'starter-v2',
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
    contentVersion: 'starter-v2',
    expeditionId: 'starter-expedition-v1',
    expeditionStatus: 'COMPLETED',
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
    serverTime: '2026-07-26T10:00:00Z',
  );
}
