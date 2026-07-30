import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command_runtime.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command_store.dart';
import 'package:walking_rpg_mobile/features/activity/domain/activity_sync_result.dart';
import 'package:walking_rpg_mobile/features/activity/domain/step_reading.dart';
import 'package:walking_rpg_mobile/features/event/domain/event_resolution_result.dart';
import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';
import 'package:walking_rpg_mobile/features/onboarding/domain/first_journey_progress.dart';
import 'package:walking_rpg_mobile/features/onboarding/presentation/first_journey_gate.dart';
import 'package:walking_rpg_mobile/features/platform/domain/platform_command_result.dart';
import 'package:walking_rpg_mobile/features/platform/domain/platform_snapshot.dart';

import 'support/first_journey_fixture.dart';
import 'support/in_memory_mobile_command_store.dart';
import 'support/platform_fixture.dart';

void main() {
  testWidgets('runs real first journey actions and opens the expedition', (
    WidgetTester tester,
  ) async {
    final Set<String> completed = <String>{};
    final List<String> commands = <String>[];
    String activePetId = 'spark-v1';
    String activePetName = 'Искра';
    int stateVersion = 0;
    int resolvedEvents = 0;
    String? acknowledgedReceiptId;
    String? acknowledgementKey;
    HomeSnapshot home = firstJourneyHome();
    final InMemoryMobileCommandStore commandStore =
        InMemoryMobileCommandStore();

    PlatformSnapshot currentPlatform() {
      return platformSnapshot(
        stateVersion: stateVersion,
        completedOnboardingSteps: FirstJourneyProgress.steps
            .where(completed.contains)
            .toList(growable: false),
        activePetId: activePetId,
        resolvedEventCount: resolvedEvents,
        totalAcceptedSteps: home.dailySteps,
      );
    }

    final MobileCommandRuntime runtime = MobileCommandRuntime(
      ownerId: 'first-journey-user',
      store: commandStore,
      activitySender:
          ({required reading, required String idempotencyKey}) async =>
              throw StateError('Unexpected activity runtime call'),
      expeditionSender:
          ({
            required String expeditionId,
            required int energyToSpend,
            required String idempotencyKey,
          }) async {
            expect(expeditionId, 'starter-expedition-v1');
            expect(energyToSpend, 30);
            home = firstJourneyHome(
              synced: true,
              eventReady: true,
              petName: activePetName,
            );
            return firstJourneyAdvanceResult;
          },
      eventSender:
          ({
            required String eventId,
            required String choiceId,
            required String idempotencyKey,
          }) async {
            expect(eventId, 'signal-source-v1');
            expect(choiceId, 'analyze-signal');
            resolvedEvents = 1;
            home = firstJourneyHome(
              synced: true,
              firstEventResolved: true,
              petName: activePetName,
              petBond: 15,
            );
            return firstJourneyResolutionResult(
              petId: activePetId,
              petName: activePetName,
            );
          },
      eventResultAcknowledgementSender: ({required String receiptId}) async {
        acknowledgedReceiptId = receiptId;
        acknowledgementKey = commandStore.snapshot.single.idempotencyKey;
        return EventResultAcknowledgement(
          receiptId: receiptId,
          eventId: 'signal-source-v1',
          status: 'ACKNOWLEDGED',
          acknowledgedAt: '2026-07-29T08:03:00Z',
          serverTime: '2026-07-29T08:03:00Z',
        );
      },
      platformSender:
          ({
            required String commandType,
            required Map<String, Object?> payload,
            required String idempotencyKey,
          }) async {
            commands.add(commandType);
            if (commandType == 'COMPLETE_ONBOARDING_STEP') {
              completed.add(payload['stepId']! as String);
            } else if (commandType == 'SELECT_PET') {
              activePetId = payload['petId']! as String;
              activePetName = activePetId == 'moss-v1' ? 'Мох' : 'Искра';
              completed.add(FirstJourneyProgress.petSelectionStep);
              home = firstJourneyHome(
                synced: true,
                energy: 30,
                petName: activePetName,
              );
            }
            stateVersion += 1;
            return PlatformCommandResult(
              commandType: commandType,
              idempotencyKey: idempotencyKey,
              message: 'Команда выполнена',
              stateVersion: stateVersion,
              snapshot: currentPlatform(),
              serverTime: '2026-07-29T08:00:00Z',
            );
          },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: FirstJourneyGate(
          homeLoader: () async => home,
          platformLoader: () async => currentPlatform(),
          commandRuntime: runtime,
          synchronizer: () async {
            home = firstJourneyHome(synced: true, energy: 30);
            return firstJourneyActivityResult;
          },
          childBuilder: (VoidCallback onResume) => Scaffold(
            body: Center(
              child: FilledButton(
                key: const Key('resume-first-journey'),
                onPressed: onResume,
                child: const Text('Основная экспедиция'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tap(tester, const Key('first-journey-start'));
    expect(find.byKey(const Key('first-journey-sync')), findsOneWidget);

    await _tap(tester, const Key('first-journey-sync'));
    expect(find.text('+30 ENERGY'), findsOneWidget);
    await _tap(tester, const Key('first-journey-activity-continue'));

    expect(find.textContaining('Спокойный хранитель'), findsOneWidget);
    await _tap(tester, const Key('first-journey-select-moss-v1'));
    expect(activePetId, 'moss-v1');

    await _tap(tester, const Key('first-journey-advance'));
    expect(find.text('Источник сигнала'), findsOneWidget);

    await _tap(tester, const Key('first-journey-choice-analyze-signal'));
    expect(find.text('Частота найдена'), findsOneWidget);
    expect(find.text('+5 связи · Мох'), findsOneWidget);

    await _tap(tester, const Key('first-journey-finish'));
    expect(find.text('Основная экспедиция'), findsOneWidget);
    expect(acknowledgedReceiptId, '11111111-1111-1111-1111-111111111111');
    expect(
      acknowledgementKey,
      'first-journey-event-result-'
      '11111111-1111-1111-1111-111111111111-ack-v1',
    );
    expect(completed, containsAll(FirstJourneyProgress.steps));
    expect(commands, <String>[
      'COMPLETE_ONBOARDING_STEP',
      'COMPLETE_ONBOARDING_STEP',
      'COMPLETE_ONBOARDING_STEP',
      'SELECT_PET',
      'COMPLETE_ONBOARDING_STEP',
      'COMPLETE_ONBOARDING_STEP',
    ]);
    await runtime.close();
  });

  testWidgets('backfills fact-backed milestones after a restart', (
    WidgetTester tester,
  ) async {
    final Set<String> completed = <String>{'welcome'};
    final List<String> backfilled = <String>[];
    final HomeSnapshot home = firstJourneyHome(synced: true, energy: 30);
    final MobileCommand exposure = MobileCommand.pending(
      ownerId: 'recovery-user',
      type: MobileCommandType.platformCommand,
      idempotencyKey: 'recovery-exposure',
      fingerprint: 'recovery-exposure-fingerprint',
      payload: <String, Object?>{
        'commandType': 'RECORD_EXPERIMENT_EXPOSURE',
        'payload': <String, Object?>{
          'experimentId': 'first-journey-copy',
          'variant': 'b',
        },
      },
      now: DateTime.utc(2026, 7, 29, 8),
    );
    int exposureAttempts = 0;
    late MobileCommandRuntime runtime;

    PlatformSnapshot currentPlatform() => platformSnapshot(
      completedOnboardingSteps: FirstJourneyProgress.steps
          .where(completed.contains)
          .toList(growable: false),
      resolvedEventCount: 0,
      totalAcceptedSteps: home.dailySteps,
    );

    runtime = MobileCommandRuntime(
      ownerId: 'recovery-user',
      store: InMemoryMobileCommandStore(<MobileCommand>[exposure]),
      activitySender:
          ({required reading, required String idempotencyKey}) async =>
              throw StateError('Unexpected activity call'),
      expeditionSender:
          ({
            required String expeditionId,
            required int energyToSpend,
            required String idempotencyKey,
          }) async => throw StateError('Unexpected expedition call'),
      eventSender:
          ({
            required String eventId,
            required String choiceId,
            required String idempotencyKey,
          }) async => throw StateError('Unexpected event call'),
      platformSender:
          ({
            required String commandType,
            required Map<String, Object?> payload,
            required String idempotencyKey,
          }) async {
            if (commandType == 'RECORD_EXPERIMENT_EXPOSURE') {
              exposureAttempts += 1;
              throw StateError('telemetry offline');
            }
            final String step = payload['stepId']! as String;
            completed.add(step);
            backfilled.add(step);
            return platformCommandResult(
              commandType: commandType,
              idempotencyKey: idempotencyKey,
              snapshot: currentPlatform(),
            );
          },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: FirstJourneyGate(
          homeLoader: () async => home,
          platformLoader: () async => currentPlatform(),
          commandRuntime: runtime,
          childBuilder: (VoidCallback onResume) => const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('first-journey-pet')), findsOneWidget);
    expect(backfilled, <String>['health-permission', 'first-sync']);
    expect(exposureAttempts, 1);
    await runtime.close();
  });

  testWidgets('restarts legacy manual milestones from real player actions', (
    WidgetTester tester,
  ) async {
    final Set<String> completed = <String>{
      'welcome',
      'health-permission',
      'first-sync',
      'first-expedition',
    };
    HomeSnapshot home = firstJourneyHome();
    String activePetId = 'spark-v1';

    PlatformSnapshot currentPlatform() => platformSnapshot(
      completedOnboardingSteps: FirstJourneyProgress.steps
          .where(completed.contains)
          .toList(growable: false),
      activePetId: activePetId,
      resolvedEventCount: 0,
      totalAcceptedSteps: home.dailySteps,
    );

    final MobileCommandRuntime runtime = MobileCommandRuntime(
      ownerId: 'legacy-first-journey-user',
      store: InMemoryMobileCommandStore(),
      activitySender:
          ({required reading, required String idempotencyKey}) async =>
              throw StateError('Unexpected activity runtime call'),
      expeditionSender:
          ({
            required String expeditionId,
            required int energyToSpend,
            required String idempotencyKey,
          }) async {
            expect(expeditionId, 'starter-expedition-v1');
            expect(energyToSpend, 30);
            home = firstJourneyHome(synced: true, eventReady: true);
            return firstJourneyAdvanceResult;
          },
      eventSender:
          ({
            required String eventId,
            required String choiceId,
            required String idempotencyKey,
          }) async => throw StateError('Unexpected event call'),
      platformSender:
          ({
            required String commandType,
            required Map<String, Object?> payload,
            required String idempotencyKey,
          }) async {
            if (commandType == 'COMPLETE_ONBOARDING_STEP') {
              completed.add(payload['stepId']! as String);
            } else if (commandType == 'SELECT_PET') {
              activePetId = payload['petId']! as String;
              completed.add(FirstJourneyProgress.petSelectionStep);
            }
            return platformCommandResult(
              commandType: commandType,
              idempotencyKey: idempotencyKey,
              snapshot: currentPlatform(),
            );
          },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: FirstJourneyGate(
          homeLoader: () async => home,
          platformLoader: () async => currentPlatform(),
          commandRuntime: runtime,
          synchronizer: () async {
            home = firstJourneyHome(synced: true, energy: 30);
            return firstJourneyActivityResult;
          },
          childBuilder: (VoidCallback onResume) => const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('first-journey-activity')), findsOneWidget);
    expect(find.byKey(const Key('first-journey-event')), findsNothing);

    await _tap(tester, const Key('first-journey-sync'));
    await _tap(tester, const Key('first-journey-activity-continue'));
    expect(find.byKey(const Key('first-journey-pet')), findsOneWidget);

    await _tap(tester, const Key('first-journey-select-moss-v1'));
    expect(find.byKey(const Key('first-journey-expedition')), findsOneWidget);
    expect(find.byKey(const Key('first-journey-event')), findsNothing);

    await _tap(tester, const Key('first-journey-advance'));
    expect(find.byKey(const Key('first-journey-event')), findsOneWidget);
    expect(find.text('Источник сигнала'), findsOneWidget);
    await runtime.close();
  });

  testWidgets('keeps a completed journey open on the next local day', (
    WidgetTester tester,
  ) async {
    final HomeSnapshot home = firstJourneyHome(firstEventResolved: true);
    final PlatformSnapshot platform = platformSnapshot(
      completedOnboardingSteps: FirstJourneyProgress.steps,
      resolvedEventCount: 1,
      totalAcceptedSteps: 3000,
    );
    final MobileCommandRuntime runtime = MobileCommandRuntime(
      ownerId: 'next-day-user',
      store: InMemoryMobileCommandStore(),
      activitySender:
          ({required reading, required String idempotencyKey}) async =>
              throw StateError('Unexpected activity call'),
      expeditionSender:
          ({
            required String expeditionId,
            required int energyToSpend,
            required String idempotencyKey,
          }) async => throw StateError('Unexpected expedition call'),
      eventSender:
          ({
            required String eventId,
            required String choiceId,
            required String idempotencyKey,
          }) async => throw StateError('Unexpected event call'),
      platformSender:
          ({
            required String commandType,
            required Map<String, Object?> payload,
            required String idempotencyKey,
          }) async => throw StateError('Unexpected platform call'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: FirstJourneyGate(
          homeLoader: () async => home,
          platformLoader: () async => platform,
          commandRuntime: runtime,
          childBuilder: (VoidCallback onResume) =>
              const Scaffold(body: Text('Основная экспедиция')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(home.lastActivitySyncAt, isNull);
    expect(find.text('Основная экспедиция'), findsOneWidget);
    expect(find.byKey(const Key('first-journey-activity')), findsNothing);
    await runtime.close();
  });

  testWidgets('continues after a successful zero-step sync', (
    WidgetTester tester,
  ) async {
    final Set<String> completed = <String>{'welcome'};
    bool hasSuccessfulActivitySync = false;
    PlatformSnapshot currentPlatform() => platformSnapshot(
      completedOnboardingSteps: FirstJourneyProgress.steps
          .where(completed.contains)
          .toList(growable: false),
      resolvedEventCount: 0,
      totalAcceptedSteps: 0,
      hasSuccessfulActivitySync: hasSuccessfulActivitySync,
    );
    final MobileCommandRuntime runtime = MobileCommandRuntime(
      ownerId: 'zero-step-user',
      store: InMemoryMobileCommandStore(),
      activitySender:
          ({required reading, required String idempotencyKey}) async =>
              throw StateError('Unexpected activity call'),
      expeditionSender:
          ({
            required String expeditionId,
            required int energyToSpend,
            required String idempotencyKey,
          }) async => throw StateError('Unexpected expedition call'),
      eventSender:
          ({
            required String eventId,
            required String choiceId,
            required String idempotencyKey,
          }) async => throw StateError('Unexpected event call'),
      platformSender:
          ({
            required String commandType,
            required Map<String, Object?> payload,
            required String idempotencyKey,
          }) async {
            completed.add(payload['stepId']! as String);
            return platformCommandResult(
              commandType: commandType,
              idempotencyKey: idempotencyKey,
              snapshot: currentPlatform(),
            );
          },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: FirstJourneyGate(
          homeLoader: () async => firstJourneyHome(),
          platformLoader: () async => currentPlatform(),
          commandRuntime: runtime,
          synchronizer: () async {
            hasSuccessfulActivitySync = true;
            return const ActivitySyncResult(
              acceptedTotal: 0,
              acceptedDelta: 0,
              energyGranted: 0,
              energyBalanceAfter: 0,
              economyVersion: 0,
              riskStatus: 'NO_NEW_ACTIVITY',
              stateVersion: 0,
              serverTime: '2026-07-29T08:00:00Z',
            );
          },
          childBuilder: (VoidCallback onResume) => const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tap(tester, const Key('first-journey-sync'));
    expect(
      find.byKey(const Key('first-journey-energy-reward')),
      findsOneWidget,
    );
    await _tap(tester, const Key('first-journey-activity-continue'));

    expect(find.byKey(const Key('first-journey-pet')), findsOneWidget);
    expect(find.byKey(const Key('first-journey-activity')), findsNothing);
    await runtime.close();
  });

  testWidgets(
    'authoritative refresh preserves completed main shell without replay',
    (WidgetTester tester) async {
      final MobileCommand exposure = MobileCommand.pending(
        ownerId: 'refresh-user',
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
        now: DateTime.utc(2026, 7, 29, 8),
      );
      int exposureCalls = 0;
      int homeLoads = 0;
      int platformLoads = 0;
      int mainExperienceMounts = 0;
      int refreshGeneration = 0;
      late StateSetter setHostState;
      final Completer<void> telemetryStarted = Completer<void>();
      final Completer<void> releaseTelemetry = Completer<void>();
      final MobileCommandRuntime runtime = MobileCommandRuntime(
        ownerId: 'refresh-user',
        store: InMemoryMobileCommandStore(<MobileCommand>[exposure]),
        activitySender:
            ({required reading, required String idempotencyKey}) async =>
                throw StateError('Unexpected activity call'),
        expeditionSender:
            ({
              required String expeditionId,
              required int energyToSpend,
              required String idempotencyKey,
            }) async => throw StateError('Unexpected expedition call'),
        eventSender:
            ({
              required String eventId,
              required String choiceId,
              required String idempotencyKey,
            }) async => throw StateError('Unexpected event call'),
        platformSender:
            ({
              required String commandType,
              required Map<String, Object?> payload,
              required String idempotencyKey,
            }) async {
              exposureCalls += 1;
              telemetryStarted.complete();
              await releaseTelemetry.future;
              throw StateError('offline');
            },
      );
      final HomeSnapshot home = firstJourneyHome(
        synced: true,
        firstEventResolved: true,
      );
      final PlatformSnapshot platform = platformSnapshot(
        completedOnboardingSteps: FirstJourneyProgress.steps,
        resolvedEventCount: 1,
        totalAcceptedSteps: home.dailySteps,
        hasSuccessfulActivitySync: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              setHostState = setState;
              return FirstJourneyGate(
                homeLoader: () async {
                  homeLoads += 1;
                  return home;
                },
                platformLoader: () async {
                  platformLoads += 1;
                  return platform;
                },
                commandRuntime: runtime,
                authoritativeRefreshGeneration: refreshGeneration,
                childBuilder: (VoidCallback onResume) => _MainExperienceProbe(
                  onMount: () {
                    mainExperienceMounts += 1;
                  },
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final int homeLoadsBeforeRefresh = homeLoads;
      final int platformLoadsBeforeRefresh = platformLoads;

      expect(exposureCalls, 1);
      expect(telemetryStarted.isCompleted, isTrue);
      expect(releaseTelemetry.isCompleted, isFalse);
      expect(mainExperienceMounts, 1);
      expect(find.text('Основная экспедиция'), findsOneWidget);

      setHostState(() {
        refreshGeneration += 1;
      });
      await tester.pumpAndSettle();

      expect(exposureCalls, 1);
      expect(homeLoads, homeLoadsBeforeRefresh);
      expect(platformLoads, platformLoadsBeforeRefresh);
      expect(mainExperienceMounts, 1);
      expect(find.text('Основная экспедиция'), findsOneWidget);
      releaseTelemetry.complete();
      await runtime.close();
    },
  );

  testWidgets(
    'reload and resume reuse one startup replay for the runtime lifetime',
    (WidgetTester tester) async {
      final StepReading reading = StepReading(
        authoritativeTotal: 3000,
        localDate: DateTime(2026, 7, 29),
        timeZone: 'Europe/Berlin',
      );
      final MobileCommand activity = MobileCommand.pending(
        ownerId: 'startup-once-user',
        type: MobileCommandType.activitySync,
        idempotencyKey: 'startup-once-activity',
        fingerprint: 'startup-once-activity-fingerprint',
        payload: reading.toJson(),
        now: DateTime.utc(2026, 7, 29, 8),
      );
      final InMemoryMobileCommandStore store = InMemoryMobileCommandStore(
        <MobileCommand>[activity],
      );
      int activityCalls = 0;
      int homeLoads = 0;
      final MobileCommandRuntime runtime = MobileCommandRuntime(
        ownerId: 'startup-once-user',
        store: store,
        activitySender:
            ({
              required StepReading reading,
              required String idempotencyKey,
            }) async {
              activityCalls += 1;
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

      await tester.pumpWidget(
        MaterialApp(
          home: FirstJourneyGate(
            homeLoader: () async {
              homeLoads += 1;
              if (homeLoads == 1) {
                throw StateError('home offline');
              }
              return firstJourneyHome();
            },
            platformLoader: () async => platformSnapshot(
              resolvedEventCount: 0,
              totalAcceptedSteps: 0,
              hasSuccessfulActivitySync: false,
            ),
            commandRuntime: runtime,
            childBuilder: (VoidCallback onResume) => Scaffold(
              body: Center(
                child: FilledButton(
                  key: const Key('resume-after-startup-replay'),
                  onPressed: onResume,
                  child: const Text('Вернуться в первый путь'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('first-journey-retry')), findsOneWidget);
      expect(activityCalls, 1);
      expect(store.snapshot.single.attemptCount, 1);

      await _tap(tester, const Key('first-journey-retry'));
      expect(
        find.byKey(const Key('first-journey-continue-later')),
        findsOneWidget,
      );
      expect(activityCalls, 1);
      expect(store.snapshot.single.attemptCount, 1);

      await _tap(tester, const Key('first-journey-continue-later'));
      await _tap(tester, const Key('resume-after-startup-replay'));

      expect(
        find.byKey(const Key('first-journey-continue-later')),
        findsOneWidget,
      );
      expect(activityCalls, 1);
      expect(store.snapshot.single.attemptCount, 1);
      await runtime.close();
    },
  );

  testWidgets(
    'in-flight remount performs authoritative reads only in the new gate',
    (WidgetTester tester) async {
      final Completer<void> activityStarted = Completer<void>();
      final Completer<void> releaseActivity = Completer<void>();
      int homeLoads = 0;
      int platformLoads = 0;
      final MobileCommandRuntime runtime = _blockedStartupRuntime(
        ownerId: 'journey-remount-user',
        activityStarted: activityStarted,
        releaseActivity: releaseActivity,
      );

      Widget buildGate() {
        return MaterialApp(
          home: FirstJourneyGate(
            homeLoader: () async {
              homeLoads += 1;
              return firstJourneyHome();
            },
            platformLoader: () async {
              platformLoads += 1;
              return platformSnapshot();
            },
            commandRuntime: runtime,
            childBuilder: (VoidCallback onResume) => const SizedBox.shrink(),
          ),
        );
      }

      await tester.pumpWidget(buildGate());
      await tester.pump();
      await activityStarted.future;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(buildGate());
      await tester.pump();

      releaseActivity.complete();
      await tester.pumpAndSettle();

      expect(homeLoads, 1);
      expect(platformLoads, 1);
      expect(
        find.byKey(const Key('first-journey-continue-later')),
        findsOneWidget,
      );
      await runtime.close();
    },
  );

  testWidgets('runtime close prevents post-auth first journey reads', (
    WidgetTester tester,
  ) async {
    final Completer<void> activityStarted = Completer<void>();
    final Completer<void> releaseActivity = Completer<void>();
    int homeLoads = 0;
    int platformLoads = 0;
    final MobileCommandRuntime runtime = _blockedStartupRuntime(
      ownerId: 'journey-close-user',
      activityStarted: activityStarted,
      releaseActivity: releaseActivity,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: FirstJourneyGate(
          homeLoader: () async {
            homeLoads += 1;
            return firstJourneyHome();
          },
          platformLoader: () async {
            platformLoads += 1;
            return platformSnapshot();
          },
          commandRuntime: runtime,
          childBuilder: (VoidCallback onResume) => const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();
    await activityStarted.future;

    final Future<void> closing = runtime.close();
    releaseActivity.complete();
    await closing;
    await tester.pump();
    await tester.pump();

    expect(homeLoads, 0);
    expect(platformLoads, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('first-journey-retry')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('manual recovery clears the stale offline notice', (
    WidgetTester tester,
  ) async {
    final StepReading reading = StepReading(
      authoritativeTotal: 3000,
      localDate: DateTime(2026, 7, 29),
      timeZone: 'Europe/Berlin',
    );
    final MobileCommand activity = MobileCommand.pending(
      ownerId: 'notice-user',
      type: MobileCommandType.activitySync,
      idempotencyKey: 'notice-activity',
      fingerprint: 'notice-activity-fingerprint',
      payload: reading.toJson(),
      now: DateTime.utc(2026, 7, 29, 8),
    );
    final PlatformSnapshot platform = platformSnapshot(
      resolvedEventCount: 0,
      totalAcceptedSteps: 0,
      hasSuccessfulActivitySync: false,
    );
    bool online = false;
    int activityCalls = 0;
    int refreshGeneration = 0;
    late StateSetter setHostState;
    final MobileCommandRuntime runtime = MobileCommandRuntime(
      ownerId: 'notice-user',
      store: InMemoryMobileCommandStore(<MobileCommand>[activity]),
      activitySender:
          ({
            required StepReading reading,
            required String idempotencyKey,
          }) async {
            activityCalls += 1;
            if (!online) {
              throw StateError('offline');
            }
            return firstJourneyActivityResult;
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

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            setHostState = setState;
            return FirstJourneyGate(
              homeLoader: () async => firstJourneyHome(),
              platformLoader: () async => platform,
              commandRuntime: runtime,
              authoritativeRefreshGeneration: refreshGeneration,
              childBuilder: (VoidCallback onResume) => Scaffold(
                body: Center(
                  child: FilledButton(
                    key: const Key('resume-after-manual-recovery'),
                    onPressed: onResume,
                    child: const Text('Вернуться в первый путь'),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('ждёт соединения'), findsOneWidget);
    expect(activityCalls, 1);

    online = true;
    final MobileCommandReplayReport report = await runtime.replayPending();
    expect(report.succeeded, 1);
    setHostState(() {
      refreshGeneration += 1;
    });
    await tester.pumpAndSettle();

    expect(find.textContaining('ждёт соединения'), findsNothing);
    expect(activityCalls, 2);

    await _tap(tester, const Key('first-journey-continue-later'));
    await _tap(tester, const Key('resume-after-manual-recovery'));

    expect(find.textContaining('ждёт соединения'), findsNothing);
    expect(activityCalls, 2);
    await runtime.close();
  });

  testWidgets('corrupt command store stays private while retry loads reads', (
    WidgetTester tester,
  ) async {
    final MobileCommandRuntime runtime = MobileCommandRuntime(
      ownerId: 'corrupt-store-user',
      store: _ThrowingCommandStore(),
      activitySender:
          ({required reading, required String idempotencyKey}) async =>
              throw StateError('unused'),
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
        home: FirstJourneyGate(
          homeLoader: () async => firstJourneyHome(),
          platformLoader: () async => platformSnapshot(),
          commandRuntime: runtime,
          childBuilder: (VoidCallback onResume) => const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Локальная очередь сохранённых действий недоступна'),
      findsOneWidget,
    );
    expect(find.textContaining('/private/outbox.json'), findsNothing);
    expect(find.textContaining('private-token'), findsNothing);

    await _tap(tester, const Key('first-journey-retry'));

    expect(
      find.byKey(const Key('first-journey-continue-later')),
      findsOneWidget,
    );
    expect(find.textContaining('/private/outbox.json'), findsNothing);
    expect(find.textContaining('private-token'), findsNothing);
    await runtime.close();
  });
}

MobileCommandRuntime _blockedStartupRuntime({
  required String ownerId,
  required Completer<void> activityStarted,
  required Completer<void> releaseActivity,
}) {
  final StepReading reading = StepReading(
    authoritativeTotal: 3000,
    localDate: DateTime(2026, 7, 29),
    timeZone: 'Europe/Berlin',
  );
  return MobileCommandRuntime(
    ownerId: ownerId,
    store: InMemoryMobileCommandStore(<MobileCommand>[
      MobileCommand.pending(
        ownerId: ownerId,
        type: MobileCommandType.activitySync,
        idempotencyKey: '$ownerId-startup-activity',
        fingerprint: '$ownerId-startup-activity-fingerprint',
        payload: reading.toJson(),
        now: DateTime.utc(2026, 7, 29, 8),
      ),
    ]),
    activitySender:
        ({required StepReading reading, required String idempotencyKey}) async {
          activityStarted.complete();
          await releaseActivity.future;
          return firstJourneyActivityResult;
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
}

Future<void> _tap(WidgetTester tester, Key key) async {
  final Finder finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

final class _ThrowingCommandStore implements MobileCommandStore {
  @override
  Future<void> deleteOwner(String ownerId) async {
    throw StateError('private-token at /private/outbox.json');
  }

  @override
  Future<List<MobileCommand>> load() async {
    throw StateError('private-token at /private/outbox.json');
  }

  @override
  Future<void> save(List<MobileCommand> commands) async {
    throw StateError('private-token at /private/outbox.json');
  }
}

class _MainExperienceProbe extends StatefulWidget {
  const _MainExperienceProbe({required this.onMount});

  final VoidCallback onMount;

  @override
  State<_MainExperienceProbe> createState() => _MainExperienceProbeState();
}

class _MainExperienceProbeState extends State<_MainExperienceProbe> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Text('Основная экспедиция'));
  }
}
