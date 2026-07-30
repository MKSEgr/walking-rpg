import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command_runtime.dart';
import 'package:walking_rpg_mobile/features/activity/domain/activity_sync_result.dart';
import 'package:walking_rpg_mobile/features/activity/domain/step_reading.dart';
import 'package:walking_rpg_mobile/features/activity/presentation/activity_sync_shell.dart';

import 'support/in_memory_mobile_command_store.dart';

void main() {
  testWidgets('startup replay reloads authoritative home generation', (
    WidgetTester tester,
  ) async {
    final StepReading reading = StepReading(
      authoritativeTotal: 6842,
      localDate: DateTime(2026, 7, 26),
      timeZone: 'Europe/Berlin',
      syncCursor: 'health:2026-07-26:6842',
    );
    final InMemoryMobileCommandStore store =
        InMemoryMobileCommandStore(<MobileCommand>[
          MobileCommand.pending(
            ownerId: 'user-1',
            type: MobileCommandType.activitySync,
            idempotencyKey: 'activity-pending',
            fingerprint: 'pending-fingerprint',
            payload: reading.toJson(),
            now: DateTime.utc(2026, 7, 26, 9),
          ),
        ]);
    final MobileCommandRuntime runtime = MobileCommandRuntime(
      ownerId: 'user-1',
      store: store,
      activitySender:
          ({
            required StepReading reading,
            required String idempotencyKey,
          }) async => _activityResult(reading.authoritativeTotal),
      expeditionSender:
          ({
            required String expeditionId,
            required int energyToSpend,
            required String idempotencyKey,
          }) async => throw UnimplementedError(),
      eventSender:
          ({
            required String eventId,
            required String choiceId,
            required String idempotencyKey,
          }) async => throw UnimplementedError(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ActivitySyncShell(
          commandRuntime: runtime,
          synchronizer: () async => _activityResult(6842),
          homeBuilder: (Key key) =>
              Scaffold(key: key, body: const Text('authoritative-home')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<int>(1)), findsOneWidget);
    expect(find.textContaining('восстановлено: 1'), findsOneWidget);
    expect(store.snapshot, isEmpty);
  });

  testWidgets('shell can defer startup replay to its parent gate', (
    WidgetTester tester,
  ) async {
    final StepReading reading = StepReading(
      authoritativeTotal: 6842,
      localDate: DateTime(2026, 7, 26),
      timeZone: 'Europe/Berlin',
      syncCursor: 'health:2026-07-26:6842',
    );
    final InMemoryMobileCommandStore store =
        InMemoryMobileCommandStore(<MobileCommand>[
          MobileCommand.pending(
            ownerId: 'user-1',
            type: MobileCommandType.activitySync,
            idempotencyKey: 'activity-pending',
            fingerprint: 'pending-fingerprint',
            payload: reading.toJson(),
            now: DateTime.utc(2026, 7, 26, 9),
          ),
        ]);
    int sends = 0;
    final MobileCommandRuntime runtime = MobileCommandRuntime(
      ownerId: 'user-1',
      store: store,
      activitySender:
          ({
            required StepReading reading,
            required String idempotencyKey,
          }) async {
            sends += 1;
            throw StateError('offline');
          },
      expeditionSender:
          ({
            required String expeditionId,
            required int energyToSpend,
            required String idempotencyKey,
          }) async => throw UnimplementedError(),
      eventSender:
          ({
            required String eventId,
            required String choiceId,
            required String idempotencyKey,
          }) async => throw UnimplementedError(),
    );
    int authoritativeRefreshGeneration = 0;
    late StateSetter setHostState;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            setHostState = setState;
            return ActivitySyncShell(
              commandRuntime: runtime,
              replayOnStart: false,
              authoritativeRefreshGeneration: authoritativeRefreshGeneration,
              synchronizer: () async => _activityResult(6842),
              homeBuilder: (Key key) =>
                  Scaffold(key: key, body: const Text('authoritative-home')),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(sends, 0);
    expect(store.snapshot.single.attemptCount, 0);

    setHostState(() {
      authoritativeRefreshGeneration += 1;
    });
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<int>(1)), findsOneWidget);
    expect(sends, 0);
    expect(store.snapshot.single.attemptCount, 0);
  });

  testWidgets('existing failed record produces a non-empty recovery message', (
    WidgetTester tester,
  ) async {
    final MobileCommand failed =
        MobileCommand.pending(
          ownerId: 'user-1',
          type: MobileCommandType.activitySync,
          idempotencyKey: 'private-failed-key',
          fingerprint: 'private-failed-fingerprint',
          payload: StepReading(
            authoritativeTotal: 6842,
            localDate: DateTime(2026, 7, 26),
            timeZone: 'Europe/Berlin',
          ).toJson(),
          now: DateTime.utc(2026, 7, 26, 9),
        ).withAttemptFailure(
          now: DateTime.utc(2026, 7, 26, 9, 1),
          error: StateError('private failure'),
          terminal: true,
          category: MobileCommandFailureCategory.rejected,
        );
    final MobileCommandRuntime runtime = MobileCommandRuntime(
      ownerId: 'user-1',
      store: InMemoryMobileCommandStore(<MobileCommand>[failed]),
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
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ActivitySyncShell(
          commandRuntime: runtime,
          homeBuilder: (Key key) =>
              Scaffold(key: key, body: const Text('authoritative-home')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('требуют проверки: 1'), findsOneWidget);
    expect(find.textContaining('private-failed-key'), findsNothing);
    expect(find.text('Отложенные команды · '), findsNothing);
  });
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
