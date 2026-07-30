import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command_runtime.dart';
import 'package:walking_rpg_mobile/features/activity/domain/activity_sync_result.dart';
import 'package:walking_rpg_mobile/features/activity/domain/step_reading.dart';

import 'support/in_memory_mobile_command_store.dart';

void main() {
  test('close waits for admitted work and rejects new commands', () async {
    final Completer<ActivitySyncResult> response =
        Completer<ActivitySyncResult>();
    final MobileCommandRuntime runtime = MobileCommandRuntime(
      ownerId: 'owner-1',
      store: InMemoryMobileCommandStore(),
      activitySender:
          ({required StepReading reading, required String idempotencyKey}) =>
              response.future,
      expeditionSender:
          ({
            required String expeditionId,
            required int energyToSpend,
            required String idempotencyKey,
          }) async => throw StateError('unused'),
      eventSender:
          ({
            required String eventId,
            required String choiceId,
            required String idempotencyKey,
          }) async => throw StateError('unused'),
    );
    final StepReading reading = StepReading(
      authoritativeTotal: 1200,
      localDate: DateTime.utc(2026, 7, 28),
      timeZone: 'UTC',
    );

    final Future<ActivitySyncResult> operation = runtime.syncActivity(
      reading: reading,
      idempotencyKey: 'sync-1',
    );
    await Future<void>.delayed(Duration.zero);
    bool closeCompleted = false;
    final Future<void> closing = runtime.close().then((void _) {
      closeCompleted = true;
    });
    await Future<void>.delayed(Duration.zero);

    expect(closeCompleted, isFalse);
    expect(
      () => runtime.syncActivity(reading: reading, idempotencyKey: 'sync-2'),
      throwsA(isA<StateError>()),
    );

    response.complete(
      const ActivitySyncResult(
        acceptedTotal: 1200,
        acceptedDelta: 1200,
        energyGranted: 12,
        energyBalanceAfter: 12,
        economyVersion: 1,
        riskStatus: 'ACCEPTED',
        stateVersion: 1,
        serverTime: '2026-07-28T10:00:00Z',
      ),
    );
    await operation;
    await closing;

    expect(closeCompleted, isTrue);
    await runtime.close();
  });

  test('closing runtime suppresses changes from admitted work', () async {
    final Completer<ActivitySyncResult> response =
        Completer<ActivitySyncResult>();
    final InMemoryMobileCommandStore store = InMemoryMobileCommandStore();
    final MobileCommandRuntime runtime = MobileCommandRuntime(
      ownerId: 'owner-1',
      store: store,
      activitySender:
          ({required StepReading reading, required String idempotencyKey}) =>
              response.future,
      expeditionSender:
          ({
            required String expeditionId,
            required int energyToSpend,
            required String idempotencyKey,
          }) async => throw StateError('unused'),
      eventSender:
          ({
            required String eventId,
            required String choiceId,
            required String idempotencyKey,
          }) async => throw StateError('unused'),
    );
    int changes = 0;
    final StreamSubscription<void> subscription = runtime.changes.listen((
      void _,
    ) {
      changes += 1;
    });
    final StepReading reading = StepReading(
      authoritativeTotal: 1200,
      localDate: DateTime.utc(2026, 7, 28),
      timeZone: 'UTC',
    );

    final Future<ActivitySyncResult> operation = runtime.syncActivity(
      reading: reading,
      idempotencyKey: 'sync-closing',
    );
    await Future<void>.delayed(Duration.zero);
    expect(changes, 1);

    final Future<void> operationFailure = expectLater(
      operation,
      throwsStateError,
    );
    final Future<void> closing = runtime.close();
    response.completeError(StateError('session rejected'));
    await operationFailure;
    await closing;
    await Future<void>.delayed(Duration.zero);

    expect(changes, 1);
    expect(store.snapshot.single.attemptCount, 1);
    await subscription.cancel();
  });

  test(
    'close waits for memoized startup state replay and rejects cached access',
    () async {
      final StepReading reading = StepReading(
        authoritativeTotal: 1200,
        localDate: DateTime.utc(2026, 7, 28),
        timeZone: 'UTC',
      );
      final MobileCommand activity = MobileCommand.pending(
        ownerId: 'owner-1',
        type: MobileCommandType.activitySync,
        idempotencyKey: 'startup-activity',
        fingerprint: 'startup-activity-fingerprint',
        payload: reading.toJson(),
        now: DateTime.utc(2026, 7, 28, 10),
      );
      final InMemoryMobileCommandStore store = InMemoryMobileCommandStore(
        <MobileCommand>[activity],
      );
      final Completer<void> activityStarted = Completer<void>();
      final Completer<void> releaseActivity = Completer<void>();
      int activityCalls = 0;
      final MobileCommandRuntime runtime = MobileCommandRuntime(
        ownerId: 'owner-1',
        store: store,
        activitySender:
            ({
              required StepReading reading,
              required String idempotencyKey,
            }) async {
              activityCalls += 1;
              activityStarted.complete();
              await releaseActivity.future;
              throw StateError('activity offline');
            },
        expeditionSender:
            ({
              required String expeditionId,
              required int energyToSpend,
              required String idempotencyKey,
            }) async => throw StateError('unused'),
        eventSender:
            ({
              required String eventId,
              required String choiceId,
              required String idempotencyKey,
            }) async => throw StateError('unused'),
      );
      int changes = 0;
      bool streamClosed = false;
      final StreamSubscription<void> subscription = runtime.changes.listen(
        (void _) {
          changes += 1;
        },
        onDone: () {
          streamClosed = true;
        },
      );

      final Future<MobileCommandReplayReport> firstReplay = runtime
          .replayPendingOnStart();
      final Future<MobileCommandReplayReport> repeatedReplay = runtime
          .replayPendingOnStart();
      expect(identical(firstReplay, repeatedReplay), isTrue);
      await activityStarted.future;

      bool closeCompleted = false;
      final Future<void> closing = runtime.close().then((void _) {
        closeCompleted = true;
      });
      await Future<void>.delayed(Duration.zero);

      expect(closeCompleted, isFalse);
      expect(() => runtime.replayPendingOnStart(), throwsA(isA<StateError>()));

      releaseActivity.complete();
      final List<MobileCommandReplayReport> reports = await Future.wait(
        <Future<MobileCommandReplayReport>>[firstReplay, repeatedReplay],
      );
      await closing;
      await Future<void>.delayed(Duration.zero);

      expect(reports[1], same(reports[0]));
      expect(reports[0].retryableFailures, 1);
      expect(activityCalls, 1);
      expect(store.snapshot.single.attemptCount, 1);
      expect(changes, 0);
      expect(closeCompleted, isTrue);
      expect(streamClosed, isTrue);
      await subscription.cancel();
    },
  );

  test(
    'close waits for detached startup telemetry and suppresses late changes',
    () async {
      final MobileCommand telemetry = MobileCommand.pending(
        ownerId: 'owner-1',
        type: MobileCommandType.platformCommand,
        idempotencyKey: 'exposure-1',
        fingerprint: 'exposure-fingerprint',
        payload: <String, Object?>{
          'commandType': 'RECORD_EXPERIMENT_EXPOSURE',
          'payload': <String, Object?>{
            'experimentId': 'first-journey-copy',
            'variant': 'b',
          },
        },
        now: DateTime.utc(2026, 7, 28, 10),
      );
      final InMemoryMobileCommandStore store = InMemoryMobileCommandStore(
        <MobileCommand>[telemetry],
      );
      final Completer<void> telemetryStarted = Completer<void>();
      final Completer<void> releaseTelemetry = Completer<void>();
      int telemetryCalls = 0;
      final MobileCommandRuntime runtime = MobileCommandRuntime(
        ownerId: 'owner-1',
        store: store,
        activitySender:
            ({
              required StepReading reading,
              required String idempotencyKey,
            }) async => throw StateError('unused'),
        expeditionSender:
            ({
              required String expeditionId,
              required int energyToSpend,
              required String idempotencyKey,
            }) async => throw StateError('unused'),
        eventSender:
            ({
              required String eventId,
              required String choiceId,
              required String idempotencyKey,
            }) async => throw StateError('unused'),
        platformSender:
            ({
              required String commandType,
              required Map<String, Object?> payload,
              required String idempotencyKey,
            }) async {
              telemetryCalls += 1;
              telemetryStarted.complete();
              await releaseTelemetry.future;
              throw StateError('telemetry offline');
            },
      );
      int changes = 0;
      bool streamClosed = false;
      final StreamSubscription<void> subscription = runtime.changes.listen(
        (void _) {
          changes += 1;
        },
        onDone: () {
          streamClosed = true;
        },
      );

      final MobileCommandReplayReport startupReplay = await runtime
          .replayPendingOnStart();
      await telemetryStarted.future;
      expect(startupReplay.pendingAfter, 1);
      expect(changes, 0);

      final MobileCommandReplayReport repeatedStartupReplay = await runtime
          .replayPendingOnStart();
      expect(repeatedStartupReplay.pendingAfter, 1);
      expect(telemetryCalls, 1);

      bool closeCompleted = false;
      final Future<void> closing = runtime.close().then((void _) {
        closeCompleted = true;
      });
      await Future<void>.delayed(Duration.zero);

      expect(closeCompleted, isFalse);
      expect(streamClosed, isFalse);

      releaseTelemetry.complete();
      await closing;
      await Future<void>.delayed(Duration.zero);

      expect(closeCompleted, isTrue);
      expect(streamClosed, isTrue);
      expect(changes, 0);
      expect(telemetryCalls, 1);
      expect(store.snapshot.single.attemptCount, 1);
      await subscription.cancel();
    },
  );
}
