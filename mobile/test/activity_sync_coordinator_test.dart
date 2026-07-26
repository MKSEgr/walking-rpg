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

  @override
  Future<StepReading> read() async => reading;
}
