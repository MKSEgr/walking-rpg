import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/core/commands/mobile_command_runtime.dart';
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
    HomeSnapshot home = firstJourneyHome();

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
    await runtime.close();
  });
}

Future<void> _tap(WidgetTester tester, Key key) async {
  final Finder finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
