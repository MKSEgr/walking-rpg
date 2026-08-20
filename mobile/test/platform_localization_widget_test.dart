import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/core/localization/current_platform_content_localizations.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';
import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';
import 'package:walking_rpg_mobile/features/platform/domain/platform_command_result.dart';
import 'package:walking_rpg_mobile/features/platform/domain/platform_snapshot.dart';
import 'package:walking_rpg_mobile/features/platform/presentation/platform_screen.dart';
import 'package:walking_rpg_mobile/l10n/generated/app_localizations.dart';

import 'support/platform_fixture.dart';

void main() {
  testWidgets('current Platform catalog resolves every reviewed stable ID', (
    WidgetTester tester,
  ) async {
    for (final Locale locale in const <Locale>[Locale('ru'), Locale('en')]) {
      late AppLocalizations l10n;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (BuildContext context) {
              l10n = AppLocalizations.of(context)!;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final String stepId in _onboardingStepIds) {
        expect(
          l10n.currentPlatformOnboardingStep(stepId, _fallback),
          isNot(_fallback),
          reason: '${locale.languageCode} onboarding step $stepId',
        );
      }
      for (final String skillId in _skillIds) {
        expect(
          l10n.currentPlatformSkillName(skillId, _fallback),
          isNot(_fallback),
          reason: '${locale.languageCode} skill name $skillId',
        );
        expect(
          l10n.currentPlatformSkillDescription(skillId, _fallback),
          isNot(_fallback),
          reason: '${locale.languageCode} skill description $skillId',
        );
      }
      for (final String questId in _questIds) {
        expect(
          l10n.currentPlatformQuestName(questId, _fallback),
          isNot(_fallback),
          reason: '${locale.languageCode} quest $questId',
        );
      }
      for (final String achievementId in _achievementIds) {
        expect(
          l10n.currentPlatformAchievementName(achievementId, _fallback),
          isNot(_fallback),
          reason: '${locale.languageCode} achievement $achievementId',
        );
      }
      for (final String cosmeticId in _cosmeticIds) {
        expect(
          l10n.currentPlatformCosmeticName(cosmeticId, _fallback),
          isNot(_fallback),
          reason: '${locale.languageCode} cosmetic $cosmeticId',
        );
      }
      for (final String experimentId in _experimentIds) {
        expect(
          l10n.currentPlatformExperimentDescription(experimentId, _fallback),
          isNot(_fallback),
          reason: '${locale.languageCode} experiment $experimentId',
        );
      }
      for (final String commandType in _commandTypes) {
        expect(
          l10n.currentPlatformCommandMessage(commandType, _fallback),
          isNot(_fallback),
          reason: '${locale.languageCode} command $commandType',
        );
      }

      expect(
        l10n.currentPlatformSeasonName('signal-season-1', _fallback),
        isNot(_fallback),
      );
    }
  });

  testWidgets('future Platform identities preserve literal server copy', (
    WidgetTester tester,
  ) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) {
            l10n = AppLocalizations.of(context)!;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      l10n.currentPlatformOnboardingStep('future-step', _fallback),
      _fallback,
    );
    expect(l10n.currentPlatformSkillName('future-skill', _fallback), _fallback);
    expect(l10n.currentPlatformQuestName('future-quest', _fallback), _fallback);
    expect(
      l10n.currentPlatformAchievementName('future-achievement', _fallback),
      _fallback,
    );
    expect(
      l10n.currentPlatformCosmeticName('future-cosmetic', _fallback),
      _fallback,
    );
    expect(
      l10n.currentPlatformSeasonName('future-season', _fallback),
      _fallback,
    );
    expect(
      l10n.currentPlatformExperimentDescription('future-experiment', _fallback),
      _fallback,
    );
    expect(
      l10n.currentPlatformCommandMessage('FUTURE_COMMAND', _fallback),
      _fallback,
    );
  });

  testWidgets('journey completion time follows the RU and EN locale', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const HomeJourneyFinalDecision currentFinal = HomeJourneyFinalDecision(
      eventId: 'echo-vault-v1',
      eventTitle: 'Persisted current finale',
      choiceId: 'stabilize-core',
      choiceTitle: 'Persisted current choice',
      outcomeTitle: 'Persisted current outcome',
      outcomeSummary: 'Persisted current summary.',
      resolvedAt: '2026-08-19T10:00:00Z',
    );
    const HomeJourneyFinalDecision archivedFinal = HomeJourneyFinalDecision(
      eventId: 'mirror-delta-v1',
      eventTitle: 'Persisted archived finale',
      choiceId: 'follow-reflection',
      choiceTitle: 'Persisted archived choice',
      outcomeTitle: 'Persisted archived outcome',
      outcomeSummary: 'Persisted archived summary.',
      resolvedAt: '2026-08-18T08:30:00Z',
    );

    for (final Locale locale in const <Locale>[Locale('ru'), Locale('en')]) {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _LocalizedPlatformApp(
          locale: locale,
          textScale: 1.6,
          child: PlatformScreen(
            loader: () async => platformSnapshot(),
            homeLoader: () async => _homeWithPersistedDecision(
              completionRecap: const HomeExpeditionCompletionRecap(
                journeyNumber: 7,
                decisionCount: 1,
                finalDecision: currentFinal,
                pilotExperienceGained: 0,
                petBondGained: 0,
                materials: <HomeJourneyMaterialReward>[],
              ),
              recentJourneyRecaps: const <HomeExpeditionCompletionRecap>[
                HomeExpeditionCompletionRecap(
                  journeyNumber: 6,
                  decisionCount: 1,
                  decisions: <HomeExpeditionDecisionLogEntry>[
                    HomeExpeditionDecisionLogEntry(
                      eventId: 'mirror-delta-v1',
                      eventTitle: 'Persisted archived finale',
                      choiceId: 'follow-reflection',
                      choiceTitle: 'Persisted archived choice',
                      outcomeTitle: 'Persisted archived outcome',
                      outcomeSummary: 'Persisted archived summary.',
                      resolvedAt: '2026-08-18T08:30:00Z',
                    ),
                  ],
                  finalDecision: archivedFinal,
                  pilotExperienceGained: 0,
                  petBondGained: 0,
                  materials: <HomeJourneyMaterialReward>[],
                ),
              ],
            ),
            recordExperimentExposures: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Finder current = find.byKey(
        const Key('platform-journey-completion-recap'),
      );
      await _bringIntoView(tester, current);
      final String currentLabel = _formattedCompletionTime(
        tester,
        current,
        currentFinal.resolvedAt,
        russian: locale.languageCode == 'ru',
      );
      expect(find.text(currentLabel), findsOneWidget);
      final String currentSemanticPrefix = locale.languageCode == 'ru'
          ? 'Поход 7 завершён. Принято решений: 1'
          : 'Journey 7 completed. Decisions made: 1';
      expect(
        find.bySemanticsLabel(
          RegExp(
            '^${RegExp.escape(currentSemanticPrefix)}\\. '
            '${RegExp.escape(currentLabel)}\\.',
          ),
        ),
        findsOneWidget,
      );
      final Finder currentDecision = find.byKey(
        const Key('platform-journey-decision-legacy-event-v1'),
      );
      await _bringIntoView(tester, currentDecision);
      final String currentDecisionLabel = _formattedDecisionTime(
        tester,
        currentDecision,
        '2026-08-19T10:00:00Z',
        russian: locale.languageCode == 'ru',
      );
      expect(find.text(currentDecisionLabel), findsOneWidget);
      expect(
        find.byKey(
          const Key('platform-journey-decision-legacy-event-v1-time'),
        ),
        findsOneWidget,
      );

      final Finder archived = find.byKey(
        const Key('platform-journey-archive-6'),
      );
      await _bringIntoView(tester, archived);
      final String archivedLabel = _formattedCompletionTime(
        tester,
        archived,
        archivedFinal.resolvedAt,
        russian: locale.languageCode == 'ru',
      );
      expect(find.text(archivedLabel), findsOneWidget);
      expect(
        find.byKey(const Key('platform-journey-archive-6-time')),
        findsOneWidget,
      );
      final Finder historyToggle = find.byKey(
        const Key('platform-journey-archive-6-history-toggle'),
      );
      await _bringIntoView(tester, historyToggle);
      await tester.tap(historyToggle);
      await tester.pumpAndSettle();
      final Finder archivedDecision = find.byKey(
        const Key('platform-journey-decision-mirror-delta-v1'),
      );
      await _bringIntoView(tester, archivedDecision);
      final String archivedDecisionLabel = _formattedDecisionTime(
        tester,
        archivedDecision,
        archivedFinal.resolvedAt,
        russian: locale.languageCode == 'ru',
      );
      expect(find.text(archivedDecisionLabel), findsOneWidget);
      expect(
        find.byKey(
          const Key('platform-journey-decision-mirror-delta-v1-time'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    }
  });

  testWidgets('English Platform journal stays readable at compact large text', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final SemanticsHandle semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _LocalizedPlatformApp(
        locale: const Locale('en'),
        textScale: 1.6,
        child: PlatformScreen(
          loader: () async => platformSnapshot(includeProfileCosmetics: true),
          homeLoader: () async => _homeWithPersistedDecision(
            completionRecap: const HomeExpeditionCompletionRecap(
              journeyNumber: 7,
              decisionCount: 2,
              pilotExperienceGained: 60,
              pilotExperienceRewards: <HomeJourneyPilotExperienceReward>[
                HomeJourneyPilotExperienceReward(
                  pilotId: 'navigator-v1',
                  pilotName: 'Navigator from journey',
                  experienceGained: 45,
                ),
                HomeJourneyPilotExperienceReward(
                  pilotId: 'archivist-v1',
                  pilotName: 'Archivist from journey',
                  experienceGained: 15,
                ),
              ],
              petBondGained: 0,
              materials: <HomeJourneyMaterialReward>[],
            ),
            journeyChronicle: const HomeJourneyChronicle(
              completedJourneyCount: 9,
              decisionCount: 31,
              pilotExperienceGained: 620,
              petBondGained: 205,
              pilotExperienceRewards: <HomeJourneyPilotExperienceReward>[
                HomeJourneyPilotExperienceReward(
                  pilotId: 'navigator-v1',
                  pilotName: 'Navigator from chronicle',
                  experienceGained: 500,
                ),
                HomeJourneyPilotExperienceReward(
                  pilotId: 'archivist-v1',
                  pilotName: 'Archivist from chronicle',
                  experienceGained: 120,
                ),
              ],
              petBondRewards: <HomeJourneyPetBondReward>[
                HomeJourneyPetBondReward(
                  petId: 'spark-v1',
                  petName: 'Spark',
                  bondGained: 120,
                ),
                HomeJourneyPetBondReward(
                  petId: 'moss-v1',
                  petName: 'Moss',
                  bondGained: 85,
                ),
              ],
              materials: <HomeJourneyMaterialReward>[
                HomeJourneyMaterialReward(
                  itemId: 'lumen-shard',
                  itemName: 'Lumen Shard',
                  quantity: 44,
                ),
                HomeJourneyMaterialReward(
                  itemId: 'ash-seed',
                  itemName: 'Ash Seed',
                  quantity: 19,
                ),
              ],
              decisionOutcomes: <HomeJourneyDecisionOutcome>[
                HomeJourneyDecisionOutcome(
                  eventId: 'signal-source-v1',
                  eventTitle: 'Outer Signal',
                  choiceId: 'decode-signal',
                  choiceTitle: 'Decode the signal',
                  outcomeTitle: 'Route charted',
                  decisionCount: 18,
                ),
                HomeJourneyDecisionOutcome(
                  eventId: 'ash-orbit-v1',
                  eventTitle: 'Ash Orbit',
                  choiceId: 'hold-ember',
                  choiceTitle: 'Hold the ember',
                  outcomeTitle: 'Orbit crossed',
                  decisionCount: 13,
                ),
              ],
              finaleOutcomes: <HomeJourneyFinaleOutcome>[
                HomeJourneyFinaleOutcome(
                  eventId: 'echo-vault-v1',
                  eventTitle: 'Beacon Heart',
                  choiceId: 'stabilize-core',
                  choiceTitle: 'Stabilize the core',
                  outcomeTitle: 'Steady pulse',
                  journeyCount: 5,
                ),
                HomeJourneyFinaleOutcome(
                  eventId: 'mirror-delta-v1',
                  eventTitle: 'Mirror Delta',
                  choiceId: 'follow-reflection',
                  choiceTitle: 'Follow the reflection',
                  outcomeTitle: 'Reflection accepted',
                  journeyCount: 4,
                ),
              ],
            ),
          ),
          recordExperimentExposures: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Journal'), findsOneWidget);
    expect(find.text('PILOT JOURNAL'), findsOneWidget);
    expect(find.text('Season of the First Signal'), findsOneWidget);
    expect(find.text('SPARK · LV. 1'), findsOneWidget);

    await _bringIntoView(
      tester,
      find.byKey(const Key('platform-journey-completion-recap')),
    );
    expect(find.text('Navigator from journey · +45 XP'), findsOneWidget);
    expect(find.text('Archivist from journey · +15 XP'), findsOneWidget);
    expect(find.text('+60 pilot XP'), findsNothing);
    expect(
      find.bySemanticsLabel(
        'Journey 7 completed. Decisions made: 2. '
        'Total rewards: Navigator from journey: +45 pilot XP; '
        'Archivist from journey: +15 pilot XP.',
      ),
      findsOneWidget,
    );

    await _bringIntoView(
      tester,
      find.byKey(const Key('platform-journey-chronicle')),
    );
    expect(find.text('Journey chronicle'), findsOneWidget);
    expect(find.text('Navigator from chronicle · +500 XP'), findsOneWidget);
    expect(find.text('Archivist from chronicle · +120 XP'), findsOneWidget);
    expect(find.text('+620 pilot XP'), findsNothing);
    expect(find.text('Spark · +120 bond'), findsOneWidget);
    expect(find.text('Moss · +85 bond'), findsOneWidget);
    expect(find.text('+205 companion bond'), findsNothing);
    expect(find.text('+44 Lumen Shard'), findsOneWidget);
    expect(find.text('+19 Ash Seed'), findsOneWidget);
    expect(find.text('Lifetime decisions'), findsOneWidget);
    expect(
      find.text('Decode the signal → Route charted · ×18'),
      findsOneWidget,
    );
    expect(find.text('Hold the ember → Orbit crossed · ×13'), findsOneWidget);
    expect(find.text('Route finales'), findsOneWidget);
    expect(find.text('Stabilize the core → Steady pulse · ×5'), findsOneWidget);
    expect(
      find.text('Follow the reflection → Reflection accepted · ×4'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Journey chronicle. Journeys completed: 9. Decisions made: 31. '
        'Total rewards: Navigator from chronicle: +500 pilot XP; '
        'Archivist from chronicle: +120 pilot XP; '
        'Spark: +120 bond; Moss: +85 bond; '
        '+44 Lumen Shard; +19 Ash Seed. Lifetime decisions: Outer Signal. '
        'Decision: Decode the signal. Outcome: Route charted. Decisions: 18; '
        'Ash Orbit. Decision: Hold the ember. Outcome: Orbit crossed. '
        'Decisions: 13. Route finales: Beacon Heart. '
        'Decision: Stabilize the core. Outcome: Steady pulse. Journeys: 5; '
        'Mirror Delta. Decision: Follow the reflection. '
        'Outcome: Reflection accepted. Journeys: 4.',
      ),
      findsOneWidget,
    );

    await _bringIntoView(
      tester,
      find.byKey(const Key('platform-onboarding-step-welcome')),
    );
    expect(
      find.bySemanticsLabel('Meet the Navigator: completed'),
      findsOneWidget,
    );

    await _bringIntoView(
      tester,
      find.byKey(const Key('platform-advance-weekly')),
    );
    expect(
      find.bySemanticsLabel(
        'Weekly route “Season of the First Signal”: 40 of 100 ENERGY',
      ),
      findsOneWidget,
    );

    await _bringIntoView(
      tester,
      find.byKey(const Key('platform-pet-compact-spark-v1')),
    );
    expect(find.text('Spark · level 1'), findsOneWidget);
    expect(find.text('lumin · Sensitive scout'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Companion “Spark” bond: 50 of 50. Ready to evolve',
      ),
      findsOneWidget,
    );

    await _bringIntoView(
      tester,
      find.byKey(const Key('platform-skill-compact-steady-step')),
    );
    expect(find.text('Steady Step'), findsOneWidget);
    expect(find.text('SKILL UNLOCKED'), findsOneWidget);

    await _bringIntoView(
      tester,
      find.byKey(const Key('platform-quest-compact-walk-3000')),
    );
    expect(find.text('First Route'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Quest “First Route” progress: 3000 of 3000'),
      findsOneWidget,
    );

    await _bringIntoView(
      tester,
      find.byKey(const Key('platform-cosmetic-compact-pilot-scarf')),
    );
    expect(find.text('Navigator Scarf'), findsOneWidget);
    expect(find.text('Equipped'), findsOneWidget);

    await _bringIntoView(
      tester,
      find.byKey(const Key('platform-achievement-onboarding-complete')),
    );
    expect(find.text('Path Open'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Achievement “Path Open”: locked'),
      findsOneWidget,
    );

    await _bringIntoView(tester, find.text('Experiments and configuration'));
    await tester.tap(find.text('Experiments and configuration'));
    await tester.pumpAndSettle();
    expect(find.text('Home energy panel copy'), findsOneWidget);
    expect(find.text('Quest card information order'), findsOneWidget);
    expect(tester.takeException(), isNull);

    semantics.dispose();
  });

  testWidgets('known command feedback ignores Russian backend message in EN', (
    WidgetTester tester,
  ) async {
    final PlatformSnapshot snapshot = platformSnapshot();
    await tester.pumpWidget(
      _LocalizedPlatformApp(
        locale: const Locale('en'),
        child: PlatformScreen(
          loader: () async => snapshot,
          homeLoader: () async => HomeSnapshot.demo,
          commandExecutor:
              ({
                required String commandType,
                required Map<String, Object?> payload,
                required String idempotencyKey,
              }) async {
                return PlatformCommandResult(
                  commandType: commandType,
                  idempotencyKey: idempotencyKey,
                  message: 'Активный питомец изменён',
                  stateVersion: snapshot.stateVersion,
                  snapshot: snapshot,
                  serverTime: snapshot.serverTime,
                );
              },
          idempotencyKeyFactory: (String commandType) => 'test-command',
          recordExperimentExposures: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder action = find.byKey(const Key('platform-select-pet-moss-v1'));
    await _bringIntoView(tester, action);
    await tester.tap(action);
    await tester.pumpAndSettle();

    expect(find.text('Active companion updated'), findsOneWidget);
    expect(find.text('Активный питомец изменён'), findsNothing);
  });

  testWidgets('English journal preserves immutable decision literals', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _LocalizedPlatformApp(
        locale: const Locale('en'),
        child: PlatformScreen(
          loader: () async => platformSnapshot(),
          homeLoader: () async => _homeWithPersistedDecision(),
          recordExperimentExposures: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Route decisions'), findsOneWidget);
    expect(find.text('Сигнал прошлого'), findsOneWidget);
    expect(find.text('Сохранённый выбор'), findsOneWidget);
    expect(find.text('Сохранённый исход'), findsOneWidget);
    final Finder decision = find.byKey(
      const Key('platform-journey-decision-legacy-event-v1'),
    );
    final String resolvedAt = _formattedDecisionTime(
      tester,
      decision,
      '2026-08-19T10:00:00Z',
      russian: false,
    );
    expect(find.text(resolvedAt), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Entry 1 of 1. Сигнал прошлого. Decision: Сохранённый выбор. '
        'Outcome: Сохранённый исход. Сохранённое описание. $resolvedAt.',
      ),
      findsOneWidget,
    );
  });
}

class _LocalizedPlatformApp extends StatelessWidget {
  const _LocalizedPlatformApp({
    required this.locale,
    required this.child,
    this.textScale = 1,
  });

  final Locale locale;
  final Widget child;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: WalkingRpgTheme.dark(),
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        );
      },
      home: child,
    );
  }
}

HomeSnapshot _homeWithPersistedDecision({
  HomeExpeditionCompletionRecap? completionRecap,
  HomeJourneyChronicle? journeyChronicle,
  List<HomeExpeditionCompletionRecap> recentJourneyRecaps =
      const <HomeExpeditionCompletionRecap>[],
}) {
  const HomeSnapshot demo = HomeSnapshot.demo;
  return HomeSnapshot(
    localDate: demo.localDate,
    timeZone: demo.timeZone,
    dailySteps: demo.dailySteps,
    dailyGoal: demo.dailyGoal,
    availableEnergy: demo.availableEnergy,
    activityStateVersion: demo.activityStateVersion,
    economyVersion: demo.economyVersion,
    lastActivitySyncAt: demo.lastActivitySyncAt,
    serverTime: demo.serverTime,
    contentVersion: demo.contentVersion,
    expeditionId: demo.expeditionId,
    expeditionName: demo.expeditionName,
    currentNodeId: demo.currentNodeId,
    currentNodeName: demo.currentNodeName,
    expeditionProgress: demo.expeditionProgress,
    requiredEnergy: demo.requiredEnergy,
    expeditionStatus: completionRecap == null
        ? demo.expeditionStatus
        : 'COMPLETED',
    expeditionVersion: demo.expeditionVersion,
    expeditionJourneyNumber: 7,
    routeTrail: demo.routeTrail,
    decisionLog: const <HomeExpeditionDecisionLogEntry>[
      HomeExpeditionDecisionLogEntry(
        eventId: 'legacy-event-v1',
        eventTitle: 'Сигнал прошлого',
        choiceId: 'legacy-choice',
        choiceTitle: 'Сохранённый выбор',
        outcomeTitle: 'Сохранённый исход',
        outcomeSummary: 'Сохранённое описание.',
        resolvedAt: '2026-08-19T10:00:00Z',
      ),
    ],
    completionRecap: completionRecap,
    recentJourneyRecaps: recentJourneyRecaps,
    journeyChronicle: journeyChronicle,
    unlockedEvent: demo.unlockedEvent,
    pilotName: demo.pilotName,
    pilotLevel: demo.pilotLevel,
    pilotCurrentExperience: demo.pilotCurrentExperience,
    pilotNextLevelExperience: demo.pilotNextLevelExperience,
    petId: demo.petId,
    petName: demo.petName,
    petSpecies: demo.petSpecies,
    petLevel: demo.petLevel,
    petBond: demo.petBond,
    petEvolutionStage: demo.petEvolutionStage,
    dailyGoalPolicy: demo.dailyGoalPolicy,
  );
}

Future<void> _bringIntoView(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

String _formattedCompletionTime(
  WidgetTester tester,
  Finder anchor,
  String resolvedAt, {
  required bool russian,
}) {
  final BuildContext context = tester.element(anchor);
  final MaterialLocalizations materialL10n = MaterialLocalizations.of(context);
  final DateTime completedAt = DateTime.parse(resolvedAt).toLocal();
  final String date = materialL10n.formatMediumDate(completedAt);
  final String time = materialL10n.formatTimeOfDay(
    TimeOfDay.fromDateTime(completedAt),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  return russian ? 'Завершён $date в $time' : 'Finished on $date at $time';
}

String _formattedDecisionTime(
  WidgetTester tester,
  Finder anchor,
  String resolvedAt, {
  required bool russian,
}) {
  final BuildContext context = tester.element(anchor);
  final MaterialLocalizations materialL10n = MaterialLocalizations.of(context);
  final DateTime decisionAt = DateTime.parse(resolvedAt).toLocal();
  final String date = materialL10n.formatMediumDate(decisionAt);
  final String time = materialL10n.formatTimeOfDay(
    TimeOfDay.fromDateTime(decisionAt),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  return russian ? 'Сохранено $date в $time' : 'Saved on $date at $time';
}

const String _fallback = 'Literal copy from a newer server';

const List<String> _onboardingStepIds = <String>[
  'welcome',
  'health-permission',
  'first-sync',
  'pet-selection',
  'first-expedition',
  'first-event',
];

const List<String> _skillIds = <String>[
  'steady-step',
  'trail-memory',
  'energy-discipline',
  'signal-reader',
];

const List<String> _questIds = <String>[
  'walk-3000',
  'walk-15000',
  'resolve-3',
  'resolve-10',
  'join-squad',
];

const List<String> _achievementIds = <String>[
  'onboarding-complete',
  'pet-friend',
  'skill-apprentice',
  'quest-runner',
  'weekly-route-complete',
  'squad-member',
  'first-cosmetic',
  'season-level-3',
];

const List<String> _cosmeticIds = <String>[
  'pilot-scarf',
  'spark-halo',
  'trail-banner',
  'dawn-frame',
];

const List<String> _experimentIds = <String>[
  'home-energy-copy-v1',
  'quest-order-v1',
];

const List<String> _commandTypes = <String>[
  'COMPLETE_ONBOARDING_STEP',
  'SELECT_PET',
  'EVOLVE_PET',
  'UNLOCK_SKILL',
  'CLAIM_QUEST',
  'ADVANCE_WEEKLY_ROUTE',
  'CREATE_SQUAD',
  'JOIN_SQUAD',
  'LEAVE_SQUAD',
  'BUY_COSMETIC',
  'PURCHASE_COSMETIC',
  'EQUIP_COSMETIC',
  'CLAIM_SEASON_REWARD',
];
