import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command_runtime.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command_store.dart';
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
          replayOnStart: true,
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

  testWidgets('remount consumes an injected runtime startup report once', (
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
            idempotencyKey: 'remount-pending',
            fingerprint: 'remount-fingerprint',
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
            return _activityResult(reading.authoritativeTotal);
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

    Widget buildShell() {
      return MaterialApp(
        home: ActivitySyncShell(
          commandRuntime: runtime,
          replayOnStart: true,
          synchronizer: () async => _activityResult(6842),
          homeBuilder: (Key key) =>
              Scaffold(key: key, body: const Text('authoritative-home')),
        ),
      );
    }

    await tester.pumpWidget(buildShell());
    await tester.pumpAndSettle();

    expect(sends, 1);
    expect(find.byKey(const ValueKey<int>(1)), findsOneWidget);
    expect(find.textContaining('восстановлено: 1'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(buildShell());
    await tester.pumpAndSettle();

    expect(sends, 1);
    expect(find.byKey(const ValueKey<int>(0)), findsOneWidget);
    expect(find.textContaining('восстановлено: 1'), findsNothing);
    await runtime.close();
  });

  testWidgets('in-flight remount receives the startup result once', (
    WidgetTester tester,
  ) async {
    final StepReading reading = StepReading(
      authoritativeTotal: 6842,
      localDate: DateTime(2026, 7, 26),
      timeZone: 'Europe/Berlin',
    );
    final InMemoryMobileCommandStore store =
        InMemoryMobileCommandStore(<MobileCommand>[
          MobileCommand.pending(
            ownerId: 'user-1',
            type: MobileCommandType.activitySync,
            idempotencyKey: 'in-flight-remount',
            fingerprint: 'in-flight-remount-fingerprint',
            payload: reading.toJson(),
            now: DateTime.utc(2026, 7, 26, 9),
          ),
        ]);
    final Completer<void> sendStarted = Completer<void>();
    final Completer<void> releaseSend = Completer<void>();
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
            sendStarted.complete();
            await releaseSend.future;
            return _activityResult(reading.authoritativeTotal);
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

    Widget buildShell() {
      return MaterialApp(
        home: ActivitySyncShell(
          commandRuntime: runtime,
          replayOnStart: true,
          synchronizer: () async => _activityResult(6842),
          homeBuilder: (Key key) =>
              Scaffold(key: key, body: const Text('authoritative-home')),
        ),
      );
    }

    await tester.pumpWidget(buildShell());
    await tester.pump();
    await sendStarted.future;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(buildShell());
    await tester.pump();

    releaseSend.complete();
    await tester.pumpAndSettle();

    expect(sends, 1);
    expect(find.byKey(const ValueKey<int>(1)), findsOneWidget);
    expect(find.textContaining('восстановлено: 1'), findsOneWidget);
    await runtime.close();
  });

  testWidgets('in-flight remount receives a privacy-safe startup error', (
    WidgetTester tester,
  ) async {
    final Completer<void> loadStarted = Completer<void>();
    final Completer<void> releaseLoad = Completer<void>();
    final MobileCommandRuntime runtime = MobileCommandRuntime(
      ownerId: 'user-1',
      store: _BlockingFailingStore(started: loadStarted, release: releaseLoad),
      activitySender:
          ({
            required StepReading reading,
            required String idempotencyKey,
          }) async => throw UnimplementedError(),
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

    Widget buildShell() {
      return MaterialApp(
        home: ActivitySyncShell(
          commandRuntime: runtime,
          replayOnStart: true,
          synchronizer: () async => _activityResult(6842),
          homeBuilder: (Key key) =>
              Scaffold(key: key, body: const Text('authoritative-home')),
        ),
      );
    }

    await tester.pumpWidget(buildShell());
    await tester.pump();
    await loadStarted.future;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(buildShell());
    await tester.pump();

    releaseLoad.complete();
    await tester.pumpAndSettle();

    expect(
      find.text('Не удалось прочитать сохранённые действия.'),
      findsOneWidget,
    );
    expect(find.textContaining('/private/outbox.json'), findsNothing);
    expect(find.textContaining('private-token'), findsNothing);
    await runtime.close();
  });

  test('automatic startup replay requires an injected runtime', () {
    expect(() => ActivitySyncShell(replayOnStart: true), throwsAssertionError);
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
          replayOnStart: true,
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

final class _BlockingFailingStore implements MobileCommandStore {
  _BlockingFailingStore({required this.started, required this.release});

  final Completer<void> started;
  final Completer<void> release;

  @override
  Future<List<MobileCommand>> load() async {
    if (!started.isCompleted) {
      started.complete();
    }
    await release.future;
    throw StateError('/private/outbox.json private-token');
  }

  @override
  Future<void> save(List<MobileCommand> commands) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteOwner(String ownerId) async {
    throw UnimplementedError();
  }
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
