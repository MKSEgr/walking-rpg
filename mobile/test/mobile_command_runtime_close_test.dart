import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
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
}
