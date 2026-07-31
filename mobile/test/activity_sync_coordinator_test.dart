import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/features/activity/application/activity_sync_coordinator.dart';
import 'package:walking_rpg_mobile/features/activity/domain/activity_sync_result.dart';
import 'package:walking_rpg_mobile/features/activity/domain/step_reading.dart';
import 'package:walking_rpg_mobile/features/activity/domain/step_source.dart';

void main() {
  test(
    'coordinator reuses key after failure and rotates it after success',
    () async {
      final _MutableStepSource source = _MutableStepSource(
        StepReading(
          authoritativeTotal: 6842,
          localDate: DateTime(2026, 7, 26),
          timeZone: 'Europe/Berlin',
          syncCursor: 'cursor-1',
        ),
      );
      final List<String> keys = <String>[];
      int attempts = 0;
      int keySequence = 0;
      final ActivitySyncCoordinator coordinator = ActivitySyncCoordinator(
        stepSource: source,
        idempotencyKeyFactory: (StepReading reading) => 'key-${++keySequence}',
        sender:
            ({
              required StepReading reading,
              required String idempotencyKey,
            }) async {
              attempts += 1;
              keys.add(idempotencyKey);
              if (attempts == 1) {
                throw StateError('network failed after send');
              }
              return _result(reading.authoritativeTotal);
            },
      );

      await expectLater(coordinator.synchronize(), throwsStateError);
      final ActivitySyncResult replayed = await coordinator.synchronize();
      final ActivitySyncResult next = await coordinator.synchronize();

      expect(replayed.acceptedTotal, 6842);
      expect(next.acceptedTotal, 6842);
      expect(keys, <String>['key-1', 'key-1', 'key-2']);
    },
  );

  test('changed reading after failure receives a new key', () async {
    final _MutableStepSource source = _MutableStepSource(
      StepReading(
        authoritativeTotal: 100,
        localDate: DateTime(2026, 7, 26),
        timeZone: 'UTC',
      ),
    );
    final List<String> keys = <String>[];
    int keySequence = 0;
    bool fail = true;
    final ActivitySyncCoordinator coordinator = ActivitySyncCoordinator(
      stepSource: source,
      idempotencyKeyFactory: (StepReading reading) => 'key-${++keySequence}',
      sender:
          ({
            required StepReading reading,
            required String idempotencyKey,
          }) async {
            keys.add(idempotencyKey);
            if (fail) {
              fail = false;
              throw StateError('temporary failure');
            }
            return _result(reading.authoritativeTotal);
          },
    );

    await expectLater(coordinator.synchronize(), throwsStateError);
    source.reading = StepReading(
      authoritativeTotal: 200,
      localDate: DateTime(2026, 7, 26),
      timeZone: 'UTC',
    );
    await coordinator.synchronize();

    expect(keys, <String>['key-1', 'key-2']);
  });

  test('explicit reading sync does not read the health source again', () async {
    final StepReading reading = StepReading(
      authoritativeTotal: 750,
      localDate: DateTime(2026, 7, 26),
      timeZone: 'Europe/Berlin',
      syncCursor: 'cursor-safe-in-memory-only',
    );
    final _MutableStepSource source = _MutableStepSource(reading);
    final ActivitySyncCoordinator coordinator = ActivitySyncCoordinator(
      stepSource: source,
      idempotencyKeyFactory: (StepReading value) => 'validation-key',
      sender:
          ({
            required StepReading reading,
            required String idempotencyKey,
          }) async => _result(reading.authoritativeTotal),
    );

    final ActivitySyncResult result = await coordinator.synchronizeReading(
      reading,
    );

    expect(result.acceptedTotal, 750);
    expect(source.readCalls, 0);
  });

  test('overlapping syncs are serialized and preserve a failed key', () async {
    final StepReading firstReading = StepReading(
      authoritativeTotal: 100,
      localDate: DateTime(2026, 7, 26),
      timeZone: 'UTC',
    );
    final StepReading secondReading = StepReading(
      authoritativeTotal: 200,
      localDate: DateTime(2026, 7, 26),
      timeZone: 'UTC',
    );
    final Completer<void> firstSendGate = Completer<void>();
    final List<String> keys = <String>[];
    int keySequence = 0;
    int sendSequence = 0;
    int activeSenders = 0;
    int maximumActiveSenders = 0;
    final ActivitySyncCoordinator coordinator = ActivitySyncCoordinator(
      stepSource: _MutableStepSource(firstReading),
      idempotencyKeyFactory: (StepReading reading) => 'key-${++keySequence}',
      sender:
          ({
            required StepReading reading,
            required String idempotencyKey,
          }) async {
            sendSequence += 1;
            final int currentSend = sendSequence;
            keys.add(idempotencyKey);
            activeSenders += 1;
            maximumActiveSenders = maximumActiveSenders < activeSenders
                ? activeSenders
                : maximumActiveSenders;
            try {
              if (currentSend == 1) {
                await firstSendGate.future;
              } else if (currentSend == 2) {
                throw StateError('ambiguous network failure');
              }
              return _result(reading.authoritativeTotal);
            } finally {
              activeSenders -= 1;
            }
          },
    );

    final Future<ActivitySyncResult> first = coordinator.synchronizeReading(
      firstReading,
    );
    final Future<ActivitySyncResult> second = coordinator.synchronizeReading(
      secondReading,
    );
    final Future<void> secondExpectation = expectLater(
      second,
      throwsStateError,
    );

    await Future<void>.delayed(Duration.zero);
    expect(keys, <String>['key-1']);
    firstSendGate.complete();
    expect((await first).acceptedTotal, 100);
    await secondExpectation;
    expect(
      (await coordinator.synchronizeReading(secondReading)).acceptedTotal,
      200,
    );

    expect(maximumActiveSenders, 1);
    expect(keys, <String>['key-1', 'key-2', 'key-2']);
  });
}

ActivitySyncResult _result(int total) {
  return ActivitySyncResult(
    acceptedTotal: total,
    acceptedDelta: total,
    energyGranted: total ~/ 100,
    energyBalanceAfter: total ~/ 100,
    economyVersion: total >= 100 ? 1 : 0,
    riskStatus: total > 0 ? 'ACCEPTED' : 'NO_NEW_ACTIVITY',
    stateVersion: total > 0 ? 1 : 0,
    serverTime: '2026-07-26T07:00:00Z',
  );
}

class _MutableStepSource implements StepSource {
  _MutableStepSource(this.reading);

  StepReading reading;
  int readCalls = 0;

  @override
  Future<StepReading> read() async {
    readCalls += 1;
    return reading;
  }
}
