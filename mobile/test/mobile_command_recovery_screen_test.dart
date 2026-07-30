import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command_runtime.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command_store.dart';
import 'package:walking_rpg_mobile/features/activity/domain/activity_sync_result.dart';
import 'package:walking_rpg_mobile/features/activity/domain/step_reading.dart';
import 'package:walking_rpg_mobile/features/recovery/presentation/mobile_command_recovery_screen.dart';

import 'support/in_memory_mobile_command_store.dart';

void main() {
  testWidgets(
    'shows durable records, retries pending and dismisses only failed',
    (WidgetTester tester) async {
      final StepReading reading = StepReading(
        authoritativeTotal: 6842,
        localDate: DateTime(2026, 7, 30),
        timeZone: 'Europe/Berlin',
        syncCursor: 'private-health-cursor',
      );
      final MobileCommand pending = MobileCommand.pending(
        ownerId: 'owner-1',
        type: MobileCommandType.activitySync,
        idempotencyKey: 'private-idempotency-key',
        fingerprint: 'private-fingerprint',
        payload: reading.toJson(),
        now: DateTime.utc(2026, 7, 30, 8),
      );
      final MobileCommand failed =
          MobileCommand.pending(
            ownerId: 'owner-1',
            type: MobileCommandType.expeditionAdvance,
            idempotencyKey: 'private-failed-key',
            fingerprint: 'private-failed-fingerprint',
            payload: <String, Object?>{
              'expeditionId': 'private-expedition',
              'energyToSpend': 30,
            },
            now: DateTime.utc(2026, 7, 30, 8, 1),
          ).withAttemptFailure(
            now: DateTime.utc(2026, 7, 30, 8, 2),
            error: StateError('private raw server error'),
            terminal: true,
            category: MobileCommandFailureCategory.rejected,
          );
      final InMemoryMobileCommandStore store = InMemoryMobileCommandStore(
        <MobileCommand>[pending, failed],
      );
      final MobileCommandRuntime runtime = _runtime(store: store);
      int authoritativeReloads = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: MobileCommandRecoveryScreen(
            runtime: runtime,
            onServerStateChanged: () {
              authoritativeReloads += 1;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Синхронизация шагов'), findsOneWidget);
      expect(find.text('Продвижение экспедиции'), findsOneWidget);
      expect(find.text('Ожидают отправки: 1 · отклонены: 1'), findsOneWidget);
      expect(find.byKey(const Key('command-recovery-retry')), findsOneWidget);
      expect(find.text('Убрать диагностическую запись'), findsOneWidget);
      expect(find.textContaining('private-idempotency-key'), findsNothing);
      expect(find.textContaining('private-health-cursor'), findsNothing);
      expect(find.textContaining('private raw server error'), findsNothing);

      await tester.tap(find.byKey(const Key('command-recovery-retry')));
      await tester.pumpAndSettle();

      expect(authoritativeReloads, 1);
      expect(find.text('Синхронизация шагов'), findsNothing);
      expect(find.text('Продвижение экспедиции'), findsOneWidget);
      expect(find.text('Ожидают отправки: 0 · отклонены: 1'), findsOneWidget);
      expect(store.snapshot.single.state, MobileCommandState.failed);

      await tester.tap(find.text('Убрать диагностическую запись'));
      await tester.pumpAndSettle();
      expect(find.text('Убрать отклонённую запись?'), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('command-recovery-dismiss-confirm')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('command-recovery-empty')), findsOneWidget);
      expect(store.snapshot, isEmpty);
    },
  );

  testWidgets('terminal retry invalidates stale authoritative state', (
    WidgetTester tester,
  ) async {
    final StepReading reading = StepReading(
      authoritativeTotal: 6842,
      localDate: DateTime(2026, 7, 30),
      timeZone: 'Europe/Berlin',
    );
    final InMemoryMobileCommandStore store =
        InMemoryMobileCommandStore(<MobileCommand>[
          MobileCommand.pending(
            ownerId: 'owner-1',
            type: MobileCommandType.activitySync,
            idempotencyKey: 'terminal-activity',
            fingerprint: 'terminal-activity-fingerprint',
            payload: reading.toJson(),
            now: DateTime.utc(2026, 7, 30, 8),
          ),
        ]);
    final MobileCommandRuntime runtime = _runtime(
      store: store,
      activitySender:
          ({
            required StepReading reading,
            required String idempotencyKey,
          }) async => throw ArgumentError('command rejected'),
    );
    int authoritativeReloads = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: MobileCommandRecoveryScreen(
          runtime: runtime,
          onServerStateChanged: () {
            authoritativeReloads += 1;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('command-recovery-retry')));
    await tester.pumpAndSettle();

    expect(authoritativeReloads, 1);
    expect(store.snapshot.single.state, MobileCommandState.failed);
    expect(find.text('Ожидают отправки: 0 · отклонены: 1'), findsOneWidget);
    await runtime.close();
  });

  testWidgets('successful replay refreshes state after screen is popped', (
    WidgetTester tester,
  ) async {
    final StepReading reading = StepReading(
      authoritativeTotal: 6842,
      localDate: DateTime(2026, 7, 30),
      timeZone: 'Europe/Berlin',
    );
    final InMemoryMobileCommandStore store =
        InMemoryMobileCommandStore(<MobileCommand>[
          MobileCommand.pending(
            ownerId: 'owner-1',
            type: MobileCommandType.activitySync,
            idempotencyKey: 'delayed-activity',
            fingerprint: 'delayed-activity-fingerprint',
            payload: reading.toJson(),
            now: DateTime.utc(2026, 7, 30, 8),
          ),
        ]);
    final Completer<void> senderStarted = Completer<void>();
    final Completer<void> releaseSender = Completer<void>();
    final MobileCommandRuntime runtime = MobileCommandRuntime(
      ownerId: 'owner-1',
      store: store,
      activitySender:
          ({
            required StepReading reading,
            required String idempotencyKey,
          }) async {
            senderStarted.complete();
            await releaseSender.future;
            return ActivitySyncResult(
              acceptedTotal: reading.authoritativeTotal,
              acceptedDelta: reading.authoritativeTotal,
              energyGranted: reading.authoritativeTotal ~/ 100,
              energyBalanceAfter: reading.authoritativeTotal ~/ 100,
              economyVersion: 1,
              riskStatus: 'ACCEPTED',
              stateVersion: 1,
              serverTime: '2026-07-30T08:10:00Z',
            );
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
    final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
    int authoritativeReloads = 0;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('launcher')),
      ),
    );
    navigatorKey.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => MobileCommandRecoveryScreen(
          runtime: runtime,
          onServerStateChanged: () {
            authoritativeReloads += 1;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('command-recovery-retry')));
    await tester.pump();
    expect(senderStarted.isCompleted, isTrue);
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('launcher'), findsOneWidget);

    releaseSender.complete();
    await tester.pumpAndSettle();

    expect(authoritativeReloads, 1);
    expect(store.snapshot, isEmpty);
    await runtime.close();
  });

  testWidgets('explicit telemetry retry stays busy until its attempt settles', (
    WidgetTester tester,
  ) async {
    final MobileCommand exposure = MobileCommand.pending(
      ownerId: 'owner-1',
      type: MobileCommandType.platformCommand,
      idempotencyKey: 'pending-exposure',
      fingerprint: 'pending-exposure-fingerprint',
      payload: <String, Object?>{
        'commandType': 'RECORD_EXPERIMENT_EXPOSURE',
        'payload': <String, Object?>{
          'experimentId': 'first-journey-copy',
          'variant': 'b',
        },
      },
      now: DateTime.utc(2026, 7, 30, 8),
    );
    final InMemoryMobileCommandStore store = InMemoryMobileCommandStore(
      <MobileCommand>[exposure],
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
    await tester.pumpWidget(
      MaterialApp(home: MobileCommandRecoveryScreen(runtime: runtime)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('command-recovery-retry')));
    await tester.pump();
    expect(telemetryStarted.isCompleted, isTrue);
    expect(telemetryCalls, 1);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('command-recovery-retry')))
          .onPressed,
      isNull,
    );
    await tester.tap(
      find.byKey(const Key('command-recovery-retry')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(telemetryCalls, 1);

    releaseTelemetry.complete();
    await tester.pumpAndSettle();

    expect(telemetryCalls, 1);
    expect(find.textContaining('ожидают сети: 1'), findsOneWidget);
    await runtime.close();
  });

  testWidgets('store corruption is visible without exposing raw diagnostics', (
    WidgetTester tester,
  ) async {
    final MobileCommandRuntime runtime = MobileCommandRuntime(
      ownerId: 'owner-1',
      store: _ThrowingStore(),
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
      MaterialApp(home: MobileCommandRecoveryScreen(runtime: runtime)),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('command-recovery-store-error')),
      findsOneWidget,
    );
    expect(find.textContaining('/root/private-outbox.json'), findsNothing);
    expect(find.textContaining('private-token'), findsNothing);
  });

  testWidgets('exposure is labelled as service telemetry without raw payload', (
    WidgetTester tester,
  ) async {
    final MobileCommand exposure =
        MobileCommand.pending(
          ownerId: 'owner-1',
          type: MobileCommandType.platformCommand,
          idempotencyKey: 'private-exposure-key',
          fingerprint: 'private-exposure-fingerprint',
          payload: <String, Object?>{
            'commandType': 'RECORD_EXPERIMENT_EXPOSURE',
            'payload': <String, Object?>{
              'experimentId': 'private-experiment',
              'variant': 'private-variant',
            },
          },
          now: DateTime.utc(2026, 7, 30, 8),
        ).withAttemptFailure(
          now: DateTime.utc(2026, 7, 30, 8, 1),
          error: StateError('private telemetry error'),
          terminal: true,
          category: MobileCommandFailureCategory.rejected,
        );
    final MobileCommandRuntime runtime = _runtime(
      store: InMemoryMobileCommandStore(<MobileCommand>[exposure]),
    );

    await tester.pumpWidget(
      MaterialApp(home: MobileCommandRecoveryScreen(runtime: runtime)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Служебная телеметрия'), findsOneWidget);
    expect(find.text('Сервис'), findsOneWidget);
    expect(find.textContaining('private-exposure-key'), findsNothing);
    expect(find.textContaining('private-experiment'), findsNothing);
    expect(find.textContaining('private telemetry error'), findsNothing);
  });
}

MobileCommandRuntime _runtime({
  required InMemoryMobileCommandStore store,
  ActivityCommandSender? activitySender,
}) {
  return MobileCommandRuntime(
    ownerId: 'owner-1',
    store: store,
    activitySender:
        activitySender ??
        ({
          required StepReading reading,
          required String idempotencyKey,
        }) async => ActivitySyncResult(
          acceptedTotal: reading.authoritativeTotal,
          acceptedDelta: reading.authoritativeTotal,
          energyGranted: reading.authoritativeTotal ~/ 100,
          energyBalanceAfter: reading.authoritativeTotal ~/ 100,
          economyVersion: 1,
          riskStatus: 'ACCEPTED',
          stateVersion: 1,
          serverTime: '2026-07-30T08:10:00Z',
        ),
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
}

final class _ThrowingStore implements MobileCommandStore {
  @override
  Future<void> deleteOwner(String ownerId) async {
    throw StateError('private-token at /root/private-outbox.json');
  }

  @override
  Future<List<MobileCommand>> load() async {
    throw StateError('private-token at /root/private-outbox.json');
  }

  @override
  Future<void> save(List<MobileCommand> commands) async {
    throw StateError('private-token at /root/private-outbox.json');
  }
}
