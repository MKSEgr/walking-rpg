import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command.dart';
import 'package:walking_rpg_mobile/features/activity/domain/step_reading.dart';

void main() {
  test('mobile command round-trips without losing durable fields', () {
    final MobileCommand original =
        MobileCommand.pending(
          ownerId: 'user-1',
          type: MobileCommandType.activitySync,
          idempotencyKey: 'activity-key',
          fingerprint: 'fingerprint',
          payload: <String, Object?>{
            'authoritativeTotal': 6842,
            'localDate': '2026-07-26',
            'timeZone': 'Europe/Berlin',
            'syncCursor': 'cursor-1',
          },
          now: DateTime.utc(2026, 7, 26, 9),
        ).withAttemptFailure(
          now: DateTime.utc(2026, 7, 26, 9, 1),
          error: StateError('network failed'),
          terminal: false,
        );

    final MobileCommand restored = MobileCommand.fromJson(original.toJson());

    expect(restored.commandId, original.commandId);
    expect(restored.ownerId, 'user-1');
    expect(restored.type, MobileCommandType.activitySync);
    expect(restored.lane, MobileCommandLane.activity);
    expect(restored.state, MobileCommandState.pending);
    expect(restored.attemptCount, 1);
    expect(restored.lastAttemptAt, DateTime.utc(2026, 7, 26, 9, 1));
    expect(restored.payload, original.payload);
  });

  test('terminal failure moves command to failed state', () {
    final MobileCommand failed =
        MobileCommand.pending(
          ownerId: 'user-1',
          type: MobileCommandType.eventResolution,
          idempotencyKey: 'event-key',
          fingerprint: 'event-fingerprint',
          payload: <String, Object?>{
            'eventId': 'event-1',
            'choiceId': 'choice-1',
          },
          now: DateTime.utc(2026, 7, 26, 9),
        ).withAttemptFailure(
          now: DateTime.utc(2026, 7, 26, 9, 1),
          error: StateError('rejected'),
          terminal: true,
        );

    expect(failed.state, MobileCommandState.failed);
    expect(failed.attemptCount, 1);
    expect(failed.lastError, contains('rejected'));
  });

  test('step reading JSON preserves the local-day identity', () {
    final StepReading reading = StepReading(
      authoritativeTotal: 6842,
      localDate: DateTime(2026, 7, 26, 18, 30),
      timeZone: 'Europe/Berlin',
      syncCursor: 'cursor-1',
    );

    final StepReading restored = StepReading.fromJson(reading.toJson());

    expect(restored, reading);
    expect(restored.localDateIso, '2026-07-26');
  });

  test('unknown command type is rejected', () {
    expect(
      () => MobileCommand.fromJson(<String, Object?>{
        'commandId': 'command-1',
        'ownerId': 'user-1',
        'type': 'UNKNOWN',
        'idempotencyKey': 'key-1',
        'fingerprint': 'fingerprint',
        'payload': <String, Object?>{},
        'state': 'PENDING',
        'attemptCount': 0,
        'createdAt': '2026-07-26T09:00:00Z',
        'updatedAt': '2026-07-26T09:00:00Z',
        'lastAttemptAt': null,
        'lastError': null,
      }),
      throwsFormatException,
    );
  });
}
