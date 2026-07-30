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
          category: MobileCommandFailureCategory.connectionOrResponse,
        );

    final MobileCommand restored = MobileCommand.fromJson(original.toJson());

    expect(restored.commandId, original.commandId);
    expect(restored.ownerId, 'user-1');
    expect(restored.type, MobileCommandType.activitySync);
    expect(restored.lane, MobileCommandLane.activity);
    expect(restored.state, MobileCommandState.pending);
    expect(restored.attemptCount, 1);
    expect(restored.lastAttemptAt, DateTime.utc(2026, 7, 26, 9, 1));
    expect(
      restored.lastFailureCategory,
      MobileCommandFailureCategory.connectionOrResponse,
    );
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
          category: MobileCommandFailureCategory.rejected,
        );

    expect(failed.state, MobileCommandState.failed);
    expect(failed.attemptCount, 1);
    expect(failed.lastError, contains('rejected'));
    expect(failed.lastFailureCategory, MobileCommandFailureCategory.rejected);
  });

  test('event result acknowledgement survives JSON persistence', () {
    final MobileCommand original = MobileCommand.pending(
      ownerId: 'user-1',
      type: MobileCommandType.eventResultAcknowledgement,
      idempotencyKey: 'ack-key',
      fingerprint: 'ack-fingerprint',
      payload: <String, Object?>{
        'receiptId': '22222222-2222-2222-2222-222222222222',
      },
      now: DateTime.utc(2026, 7, 26, 9),
    );

    final MobileCommand restored = MobileCommand.fromJson(original.toJson());

    expect(restored.type, MobileCommandType.eventResultAcknowledgement);
    expect(restored.lane, MobileCommandLane.gameplay);
    expect(
      restored.payload['receiptId'],
      '22222222-2222-2222-2222-222222222222',
    );
  });

  test('legacy exposure record gets telemetry lane without a schema bump', () {
    final MobileCommand original = MobileCommand.pending(
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
    final Map<String, Object?> legacyJson = original.toJson()
      ..remove('lastFailureCategory');

    final MobileCommand restored = MobileCommand.fromJson(legacyJson);

    expect(restored.lane, MobileCommandLane.telemetry);
    expect(restored.lastFailureCategory, isNull);
  });

  test('unknown future failure category does not corrupt the local store', () {
    final Map<String, Object?> json = MobileCommand.pending(
      ownerId: 'user-1',
      type: MobileCommandType.activitySync,
      idempotencyKey: 'activity-key',
      fingerprint: 'activity-fingerprint',
      payload: <String, Object?>{
        'authoritativeTotal': 6842,
        'localDate': '2026-07-26',
        'timeZone': 'Europe/Berlin',
        'syncCursor': 'cursor-1',
      },
      now: DateTime.utc(2026, 7, 26, 9),
    ).toJson();
    json['lastFailureCategory'] = 'FUTURE_CATEGORY';

    final MobileCommand restored = MobileCommand.fromJson(json);

    expect(restored.lastFailureCategory, isNull);
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
