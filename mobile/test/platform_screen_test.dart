import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/app/main_navigation_shell.dart';
import 'package:walking_rpg_mobile/core/cache/read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/design_system/chapter_vista.dart';
import 'package:walking_rpg_mobile/design_system/character_cosmetics.dart';
import 'package:walking_rpg_mobile/design_system/companion_bond_signal.dart';
import 'package:walking_rpg_mobile/design_system/companion_growth.dart';
import 'package:walking_rpg_mobile/design_system/companion_portrait.dart';
import 'package:walking_rpg_mobile/design_system/expedition_read_state.dart';
import 'package:walking_rpg_mobile/design_system/expedition_ui.dart';
import 'package:walking_rpg_mobile/design_system/first_journey_route_signal.dart';
import 'package:walking_rpg_mobile/design_system/pilot_motion.dart';
import 'package:walking_rpg_mobile/design_system/pilot_portrait.dart';
import 'package:walking_rpg_mobile/design_system/profile_cosmetic_art.dart';
import 'package:walking_rpg_mobile/design_system/progression_sigil.dart';
import 'package:walking_rpg_mobile/design_system/quest_route_signal.dart';
import 'package:walking_rpg_mobile/design_system/season_reward_seal.dart';
import 'package:walking_rpg_mobile/design_system/squad_formation_signal.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';
import 'package:walking_rpg_mobile/design_system/weekly_route_signal.dart';
import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';
import 'package:walking_rpg_mobile/features/platform/data/platform_api_client.dart';
import 'package:walking_rpg_mobile/features/platform/domain/platform_command_result.dart';
import 'package:walking_rpg_mobile/features/platform/domain/platform_snapshot.dart';
import 'package:walking_rpg_mobile/features/platform/presentation/platform_screen.dart';

import 'support/platform_fixture.dart';

void main() {
  testWidgets(
    'achievement summary ignores non-catalog receipts and completes',
    (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: PlatformScreen(
            loader: () async => platformSnapshot(
              achievements: const <String>[
                'onboarding-complete',
                'season-level-3',
                'season-reward-1',
              ],
            ),
            homeLoader: () async => HomeSnapshot.demo,
            recordExperimentExposures: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Finder summary = find.byKey(
        const Key('platform-achievements-summary'),
      );
      await _bringIntoView(tester, summary);
      expect(
        find.bySemanticsLabel('2 из 2 открыто. Все достижения открыты'),
        findsOneWidget,
      );
      expect(find.textContaining('3 из 2'), findsNothing);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets('journal loading waits for an accepted platform snapshot', (
    WidgetTester tester,
  ) async {
    final Completer<PlatformSnapshot> loader = Completer<PlatformSnapshot>();

    await tester.pumpWidget(
      MaterialApp(
        home: PlatformScreen(
          loader: () => loader.future,
          homeLoader: () async => HomeSnapshot.demo,
          recordExperimentExposures: false,
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('platform-loading-state')), findsOneWidget);
    expect(find.byType(ExpeditionReadState), findsOneWidget);
    expect(find.byKey(const Key('platform-journal-hero')), findsNothing);

    loader.complete(platformSnapshot());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('platform-loading-state')), findsNothing);
    expect(find.byKey(const Key('platform-journal-hero')), findsOneWidget);
    expect(find.byKey(const Key('platform-journey-archive')), findsNothing);
  });

  testWidgets('journal preserves authoritative current-journey decisions', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final HomeSnapshot home =
        _homeSnapshotWithDecisions(const <HomeExpeditionDecisionLogEntry>[
          HomeExpeditionDecisionLogEntry(
            eventId: 'outer-beacon-v1',
            eventTitle: 'Сигнал у границы',
            choiceId: 'follow-pulse',
            choiceTitle: 'Пойти за импульсом',
            outcomeTitle: 'Найден маяк',
            outcomeSummary: 'Импульс открыл безопасный путь.',
            resolvedAt: '2026-07-26T05:58:00Z',
            pilotExperienceGained: 42,
            petId: 'spark-v1',
            petName: 'Искра',
            petBondGained: 9,
            materialReward: HomeJourneyMaterialReward(
              itemId: 'echo-thread',
              itemName: 'Эхо-нити',
              quantity: 2,
            ),
          ),
          HomeExpeditionDecisionLogEntry(
            eventId: 'lumen-gate-v1',
            eventTitle: 'Люминовые ворота',
            choiceId: 'stabilize-core',
            choiceTitle: 'Стабилизировать ядро',
            outcomeTitle: 'Ровный импульс',
            outcomeSummary: 'Ворота удержали курс экспедиции.',
            resolvedAt: '2026-07-26T06:12:00Z',
            pilotExperienceGained: 18,
            petId: 'moss-v1',
            petName: 'Мох',
            petBondGained: 14,
          ),
        ], journeyNumber: 4);

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        home: PlatformScreen(
          loader: () async => platformSnapshot(),
          homeLoader: () async => home,
          recordExperimentExposures: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder log = find.byKey(const Key('platform-journey-decision-log'));
    await _bringIntoView(tester, log);
    final Finder first = find.byKey(
      const Key('platform-journey-decision-outer-beacon-v1'),
    );
    final Finder second = find.byKey(
      const Key('platform-journey-decision-lumen-gate-v1'),
    );

    expect(log, findsOneWidget);
    expect(
      find.byKey(const Key('platform-current-journey-decision-count')),
      findsOneWidget,
    );
    expect(find.text('Принято решений: 2'), findsOneWidget);
    expect(find.bySemanticsLabel('Принято решений: 2'), findsNothing);
    final Finder latest = find.byKey(
      const Key('platform-current-journey-latest-decision'),
    );
    expect(latest, findsOneWidget);
    final String latestResolvedAt = _formattedDecisionTime(
      tester,
      latest,
      '2026-07-26T06:12:00Z',
      russian: true,
    );
    expect(
      find.descendant(
        of: latest,
        matching: find.text('Последнее сохранённое решение'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: latest,
        matching: find.text('Выбрано: Стабилизировать ядро'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: latest,
        matching: find.text('Люминовые ворота → Ровный импульс'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: latest,
        matching: find.text('Результат: Ворота удержали курс экспедиции.'),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Последнее сохранённое решение текущего похода. Люминовые ворота. '
        'Выбор: Стабилизировать ядро. Итог: Ровный импульс. '
        'Результат: Ворота удержали курс экспедиции. '
        '$latestResolvedAt.',
      ),
      findsOneWidget,
    );
    final Finder journey = find.byKey(
      const Key('platform-journey-decision-journey'),
    );
    await _bringIntoView(tester, journey);
    expect(find.text('ПОХОД №4'), findsOneWidget);

    await _bringIntoView(tester, first);
    final String firstResolvedAt = _formattedDecisionTime(
      tester,
      first,
      '2026-07-26T05:58:00Z',
      russian: true,
    );
    expect(find.text('Сигнал у границы'), findsOneWidget);
    expect(find.text(firstResolvedAt), findsOneWidget);
    expect(find.text('+42 XP пилота'), findsOneWidget);
    expect(find.text('Искра · +9 связи'), findsOneWidget);
    expect(find.text('+2 Эхо-нити'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Запись 1 из 2. Сигнал у границы. '
        'Решение: Пойти за импульсом. Итог: Найден маяк. '
        'Импульс открыл безопасный путь. $firstResolvedAt. '
        'Награды: +42 XP пилота; Искра: +9 связи; +2 Эхо-нити.',
      ),
      findsOneWidget,
    );

    await _bringIntoView(tester, second);
    final String secondResolvedAt = _formattedDecisionTime(
      tester,
      second,
      '2026-07-26T06:12:00Z',
      russian: true,
    );
    expect(find.text('Люминовые ворота'), findsOneWidget);
    expect(
      find.descendant(of: second, matching: find.text(secondResolvedAt)),
      findsOneWidget,
    );
    expect(find.text('+18 XP пилота'), findsOneWidget);
    expect(find.text('Мох · +14 связи'), findsOneWidget);
    expect(tester.getTopLeft(first).dy, lessThan(tester.getTopLeft(second).dy));
    expect(
      find.bySemanticsLabel(
        'Запись 2 из 2. Люминовые ворота. '
        'Решение: Стабилизировать ядро. Итог: Ровный импульс. '
        'Ворота удержали курс экспедиции. $secondResolvedAt. '
        'Награды: +18 XP пилота; Мох: +14 связи.',
      ),
      findsOneWidget,
    );
    _expectNoLayoutException(tester);
    semantics.dispose();
  });

  testWidgets('journal shows an authoritative completed journey recap', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final HomeSnapshot home = _homeSnapshotWithDecisions(
      const <HomeExpeditionDecisionLogEntry>[
        HomeExpeditionDecisionLogEntry(
          eventId: 'outer-beacon-v1',
          eventTitle: 'Сигнал у границы',
          choiceId: 'follow-pulse',
          choiceTitle: 'Пойти за импульсом',
          outcomeTitle: 'Найден маяк',
          outcomeSummary: 'Импульс открыл безопасный путь.',
          resolvedAt: '2026-07-26T05:58:00Z',
        ),
        HomeExpeditionDecisionLogEntry(
          eventId: 'lumen-gate-v1',
          eventTitle: 'Люминовые ворота',
          choiceId: 'stabilize-core',
          choiceTitle: 'Стабилизировать ядро',
          outcomeTitle: 'Ровный импульс',
          outcomeSummary: 'Ворота удержали курс экспедиции.',
          resolvedAt: '2026-07-26T06:12:00Z',
        ),
      ],
      journeyNumber: 4,
      expeditionStatus: 'COMPLETED',
      completionRecap: const HomeExpeditionCompletionRecap(
        journeyNumber: 4,
        decisionCount: 2,
        finalDecision: HomeJourneyFinalDecision(
          eventId: 'lumen-gate-v1',
          eventTitle: 'Люминовые ворота',
          choiceId: 'stabilize-core',
          choiceTitle: 'Стабилизировать ядро',
          outcomeTitle: 'Ровный импульс',
          outcomeSummary: 'Ворота удержали курс экспедиции.',
          resolvedAt: '2026-07-26T06:12:00Z',
        ),
        durationSeconds: 3900,
        pilotExperienceGained: 60,
        pilotExperienceRewards: <HomeJourneyPilotExperienceReward>[
          HomeJourneyPilotExperienceReward(
            pilotId: 'navigator-v1',
            pilotName: 'Навигатор',
            experienceGained: 45,
          ),
          HomeJourneyPilotExperienceReward(
            pilotId: 'archivist-v1',
            pilotName: 'Архивариус',
            experienceGained: 15,
          ),
        ],
        petBondGained: 23,
        petBondRewards: <HomeJourneyPetBondReward>[
          HomeJourneyPetBondReward(
            petId: 'spark-v1',
            petName: 'Искра',
            bondGained: 9,
          ),
          HomeJourneyPetBondReward(
            petId: 'moss-v1',
            petName: 'Мох',
            bondGained: 14,
          ),
        ],
        materials: <HomeJourneyMaterialReward>[
          HomeJourneyMaterialReward(
            itemId: 'echo-thread',
            itemName: 'Эхо-нити',
            quantity: 5,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        home: PlatformScreen(
          loader: () async => platformSnapshot(),
          homeLoader: () async => home,
          recordExperimentExposures: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder recap = find.byKey(
      const Key('platform-journey-completion-recap'),
    );
    await _bringIntoView(tester, recap);

    expect(recap, findsOneWidget);
    expect(find.text('Итог похода'), findsOneWidget);
    expect(find.text('ПОХОД №4 ЗАВЕРШЁН'), findsOneWidget);
    expect(
      find.descendant(of: recap, matching: find.text('Принято решений: 2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('platform-journey-completion-final')),
      findsOneWidget,
    );
    expect(find.text('Финал маршрута'), findsOneWidget);
    expect(find.text('Стабилизировать ядро → Ровный импульс'), findsOneWidget);
    expect(find.text('Навигатор · +45 XP'), findsOneWidget);
    expect(find.text('Архивариус · +15 XP'), findsOneWidget);
    expect(find.text('+60 XP пилота'), findsNothing);
    expect(find.text('Искра · +9 связи'), findsOneWidget);
    expect(find.text('Мох · +14 связи'), findsOneWidget);
    expect(find.text('+23 связи спутников'), findsNothing);
    expect(find.text('+5 Эхо-нити'), findsOneWidget);
    final String completionTime = _formattedCompletionTime(
      tester,
      recap,
      '2026-07-26T06:12:00Z',
      russian: true,
    );
    expect(find.text(completionTime), findsOneWidget);
    expect(find.text('Длительность: 1 ч 5 мин'), findsOneWidget);
    expect(
      find.byKey(const Key('platform-journey-completion-duration')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Поход 4 завершён. Принято решений: 2. $completionTime. '
        'Длительность: 1 ч 5 мин. '
        'Финал: Люминовые ворота. Решение: Стабилизировать ядро. '
        'Исход: Ровный импульс. Ворота удержали курс экспедиции. '
        'Итоговые награды: Навигатор: +45 XP пилота; '
        'Архивариус: +15 XP пилота; Искра: +9 связи; Мох: +14 связи; '
        '+5 Эхо-нити.',
      ),
      findsOneWidget,
    );
    _expectNoLayoutException(tester);
    semantics.dispose();
  });

  testWidgets('journal shows recent completed journeys in server order', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final HomeSnapshot home = _homeSnapshotWithDecisions(
      const <HomeExpeditionDecisionLogEntry>[],
      journeyNumber: 4,
      journeyChronicle: const HomeJourneyChronicle(
        completedJourneyCount: 7,
        decisionCount: 28,
        totalDurationSeconds: 65700,
        shortestDurationSeconds: 1800,
        shortestJourneyNumber: 2,
        shortestJourneyCompletedAt: '2026-07-24T10:00:00Z',
        longestDurationSeconds: 12600,
        longestJourneyNumber: 4,
        longestJourneyCompletedAt: '2026-07-25T12:00:00Z',
        averageDurationSeconds: 9385,
        pilotExperienceGained: 420,
        petBondGained: 140,
        pilotExperienceRewards: <HomeJourneyPilotExperienceReward>[
          HomeJourneyPilotExperienceReward(
            pilotId: 'navigator-v1',
            pilotName: 'Навигатор из летописи',
            experienceGained: 360,
          ),
          HomeJourneyPilotExperienceReward(
            pilotId: 'archivist-v1',
            pilotName: 'Архивариус из летописи',
            experienceGained: 60,
          ),
        ],
        petBondRewards: <HomeJourneyPetBondReward>[
          HomeJourneyPetBondReward(
            petId: 'spark-v1',
            petName: 'Искра',
            bondGained: 80,
          ),
          HomeJourneyPetBondReward(
            petId: 'moss-v1',
            petName: 'Мох',
            bondGained: 60,
          ),
        ],
        materials: <HomeJourneyMaterialReward>[
          HomeJourneyMaterialReward(
            itemId: 'echo-thread',
            itemName: 'Эхо-нити',
            quantity: 35,
          ),
          HomeJourneyMaterialReward(
            itemId: 'ash-seed',
            itemName: 'Пепельное семя',
            quantity: 12,
          ),
        ],
        decisionOutcomes: <HomeJourneyDecisionOutcome>[
          HomeJourneyDecisionOutcome(
            eventId: 'signal-source-v1',
            eventTitle: 'Внешний сигнал из летописи',
            choiceId: 'decode-signal',
            choiceTitle: 'Расшифровать сигнал',
            outcomeTitle: 'Маршрут нанесён',
            decisionCount: 18,
          ),
          HomeJourneyDecisionOutcome(
            eventId: 'ash-orbit-v1',
            eventTitle: 'Пепельная орбита из летописи',
            choiceId: 'hold-ember',
            choiceTitle: 'Удержать искру',
            outcomeTitle: 'Орбита пройдена',
            decisionCount: 10,
          ),
        ],
        finaleOutcomes: <HomeJourneyFinaleOutcome>[
          HomeJourneyFinaleOutcome(
            eventId: 'echo-vault-v1',
            eventTitle: 'Сердце маяка из летописи',
            choiceId: 'stabilize-core',
            choiceTitle: 'Стабилизировать ядро',
            outcomeTitle: 'Ровный импульс',
            journeyCount: 4,
          ),
          HomeJourneyFinaleOutcome(
            eventId: 'mirror-delta-v1',
            eventTitle: 'Зеркальная дельта из летописи',
            choiceId: 'follow-reflection',
            choiceTitle: 'Следовать за отражением',
            outcomeTitle: 'Отражение принято',
            journeyCount: 3,
          ),
        ],
      ),
      recentJourneyRecaps: const <HomeExpeditionCompletionRecap>[
        HomeExpeditionCompletionRecap(
          journeyNumber: 3,
          decisionCount: 3,
          decisions: <HomeExpeditionDecisionLogEntry>[
            HomeExpeditionDecisionLogEntry(
              eventId: 'signal-source-v1',
              eventTitle: 'Первый сигнал второго похода',
              choiceId: 'analyze-signal',
              choiceTitle: 'Разобрать сигнал',
              outcomeTitle: 'Карта отклика',
              outcomeSummary: 'Первое решение сохранено.',
              resolvedAt: '2026-07-26T05:50:00Z',
              pilotExperienceGained: 20,
              petId: 'navigator-v1',
              petName: 'Навигатор',
              petBondGained: 5,
              materialReward: HomeJourneyMaterialReward(
                itemId: 'echo-thread',
                itemName: 'Эхо-нити',
                quantity: 1,
              ),
            ),
            HomeExpeditionDecisionLogEntry(
              eventId: 'ash-orbit-v1',
              eventTitle: 'Пепельная орбита второго похода',
              choiceId: 'hold-ember',
              choiceTitle: 'Удержать искру',
              outcomeTitle: 'Орбита пройдена',
              outcomeSummary: 'Второе решение сохранено.',
              resolvedAt: '2026-07-26T05:56:00Z',
              pilotExperienceGained: 30,
              petId: 'navigator-v1',
              petName: 'Навигатор',
              petBondGained: 7,
              materialReward: HomeJourneyMaterialReward(
                itemId: 'echo-thread',
                itemName: 'Эхо-нити',
                quantity: 2,
              ),
            ),
            HomeExpeditionDecisionLogEntry(
              eventId: 'echo-vault-v1',
              eventTitle: 'Сердце маяка',
              choiceId: 'stabilize-core',
              choiceTitle: 'Стабилизировать ядро',
              outcomeTitle: 'Ровный импульс',
              outcomeSummary: 'Второй маршрут сохранён.',
              resolvedAt: '2026-07-26T06:02:00Z',
              pilotExperienceGained: 40,
              petId: 'navigator-v1',
              petName: 'Навигатор',
              petBondGained: 9,
              materialReward: HomeJourneyMaterialReward(
                itemId: 'echo-thread',
                itemName: 'Эхо-нити',
                quantity: 3,
              ),
            ),
          ],
          finalDecision: HomeJourneyFinalDecision(
            eventId: 'echo-vault-v1',
            eventTitle: 'Сердце маяка',
            choiceId: 'stabilize-core',
            choiceTitle: 'Стабилизировать ядро',
            outcomeTitle: 'Ровный импульс',
            outcomeSummary: 'Второй маршрут сохранён.',
            resolvedAt: '2026-07-26T06:02:00Z',
          ),
          durationSeconds: 2520,
          pilotExperienceGained: 90,
          pilotExperienceRewards: <HomeJourneyPilotExperienceReward>[
            HomeJourneyPilotExperienceReward(
              pilotId: 'navigator-v1',
              pilotName: 'Навигатор из похода',
              experienceGained: 60,
            ),
            HomeJourneyPilotExperienceReward(
              pilotId: 'archivist-v1',
              pilotName: 'Архивариус из похода',
              experienceGained: 30,
            ),
          ],
          petBondGained: 21,
          petBondRewards: <HomeJourneyPetBondReward>[
            HomeJourneyPetBondReward(
              petId: 'navigator-v1',
              petName: 'Навигатор',
              bondGained: 21,
            ),
          ],
          materials: <HomeJourneyMaterialReward>[
            HomeJourneyMaterialReward(
              itemId: 'echo-thread',
              itemName: 'Эхо-нити',
              quantity: 6,
            ),
          ],
        ),
        HomeExpeditionCompletionRecap(
          journeyNumber: 2,
          decisionCount: 2,
          pilotExperienceGained: 60,
          petBondGained: 14,
          materials: <HomeJourneyMaterialReward>[],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        home: PlatformScreen(
          loader: () async => platformSnapshot(),
          homeLoader: () async => home,
          recordExperimentExposures: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder chronicle = find.byKey(
      const Key('platform-journey-chronicle'),
    );
    await _bringIntoView(tester, chronicle);
    final String recordCompletedAt = _formattedChronicleRecordTime(
      tester,
      chronicle,
      '2026-07-25T12:00:00Z',
      russian: true,
    );
    final String shortestCompletedAt = _formattedChronicleShortestTime(
      tester,
      chronicle,
      '2026-07-24T10:00:00Z',
      russian: true,
    );
    expect(chronicle, findsOneWidget);
    expect(find.text('Летопись походов'), findsOneWidget);
    expect(find.text('ЗАВЕРШЕНО · 7'), findsOneWidget);
    expect(find.text('Решений · 28'), findsOneWidget);
    expect(find.text('Время в походах: 18 ч 15 мин'), findsOneWidget);
    expect(
      find.byKey(const Key('platform-journey-chronicle-duration')),
      findsOneWidget,
    );
    expect(find.text('Самый короткий поход №2: 30 мин'), findsOneWidget);
    expect(
      find.byKey(const Key('platform-journey-chronicle-shortest-duration')),
      findsOneWidget,
    );
    expect(find.text(shortestCompletedAt), findsOneWidget);
    expect(
      find.byKey(const Key('platform-journey-chronicle-shortest-completed-at')),
      findsOneWidget,
    );
    expect(find.text('Самый долгий поход №4: 3 ч 30 мин'), findsOneWidget);
    expect(
      find.byKey(const Key('platform-journey-chronicle-longest-duration')),
      findsOneWidget,
    );
    expect(find.text(recordCompletedAt), findsOneWidget);
    expect(
      find.byKey(const Key('platform-journey-chronicle-record-completed-at')),
      findsOneWidget,
    );
    expect(find.text('В среднем за поход: 2 ч 36 мин'), findsOneWidget);
    expect(
      find.byKey(const Key('platform-journey-chronicle-average-duration')),
      findsOneWidget,
    );
    expect(find.text('Навигатор из летописи · +360 XP'), findsOneWidget);
    expect(find.text('Архивариус из летописи · +60 XP'), findsOneWidget);
    expect(find.text('+420 XP пилота'), findsNothing);
    expect(find.text('Искра · +80 связи'), findsOneWidget);
    expect(find.text('Мох · +60 связи'), findsOneWidget);
    expect(find.text('+140 связи спутников'), findsNothing);
    expect(find.text('+35 Эхо-нити'), findsOneWidget);
    expect(find.text('+12 Пепельное семя'), findsOneWidget);
    expect(find.text('Решения летописи'), findsOneWidget);
    expect(
      find.text('Расшифровать сигнал → Маршрут нанесён · ×18'),
      findsOneWidget,
    );
    expect(find.text('Удержать искру → Орбита пройдена · ×10'), findsOneWidget);
    expect(find.text('Финалы маршрутов'), findsOneWidget);
    expect(
      find.text('Стабилизировать ядро → Ровный импульс · ×4'),
      findsOneWidget,
    );
    expect(
      find.text('Следовать за отражением → Отражение принято · ×3'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Летопись походов. Завершено походов: 7. '
        'Принято решений: 28. '
        'Время в походах: 18 ч 15 мин. '
        'Самый короткий поход №2: 30 мин. '
        '$shortestCompletedAt. '
        'Самый долгий поход №4: 3 ч 30 мин. '
        '$recordCompletedAt. '
        'В среднем за поход: 2 ч 36 мин. '
        'Всего наград: Навигатор из летописи: +360 XP пилота; '
        'Архивариус из летописи: +60 XP пилота; '
        'Искра: +80 связи; Мох: +60 связи; '
        '+35 Эхо-нити; +12 Пепельное семя. Решения летописи: '
        'Внешний сигнал из летописи. Решение: Расшифровать сигнал. '
        'Исход: Маршрут нанесён. Решений: 18; '
        'Пепельная орбита из летописи. Решение: Удержать искру. '
        'Исход: Орбита пройдена. Решений: 10. Финалы маршрутов: '
        'Сердце маяка из летописи. Решение: Стабилизировать ядро. '
        'Исход: Ровный импульс. Походов: 4; '
        'Зеркальная дельта из летописи. Решение: Следовать за отражением. '
        'Исход: Отражение принято. Походов: 3.',
      ),
      findsOneWidget,
    );
    final Finder archive = find.byKey(const Key('platform-journey-archive'));
    await _bringIntoView(tester, archive);
    expect(archive, findsOneWidget);
    expect(find.text('Недавние походы'), findsOneWidget);
    expect(find.text('АРХИВ · 2'), findsOneWidget);
    final Finder latest = find.byKey(const Key('platform-journey-archive-3'));
    await _bringIntoView(tester, latest);
    expect(find.text('Поход №3'), findsOneWidget);
    final String completionTime = _formattedCompletionTime(
      tester,
      latest,
      '2026-07-26T06:02:00Z',
      russian: true,
    );
    expect(find.text(completionTime), findsOneWidget);
    expect(find.text('Длительность: 42 мин'), findsOneWidget);
    expect(
      find.byKey(const Key('platform-journey-archive-3-duration')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Поход 3. Принято решений: 3. $completionTime. '
        'Длительность: 42 мин. '
        'Финал: Сердце маяка. Решение: Стабилизировать ядро. '
        'Исход: Ровный импульс. Второй маршрут сохранён. '
        'Итоговые награды: Навигатор из похода: +60 XP пилота; '
        'Архивариус из похода: +30 XP пилота; Навигатор: +21 связи; '
        '+6 Эхо-нити.',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('platform-journey-archive-3-final')),
      findsOneWidget,
    );
    expect(find.text('Стабилизировать ядро → Ровный импульс'), findsOneWidget);
    expect(find.text('Навигатор из похода · +60 XP'), findsOneWidget);
    expect(find.text('Архивариус из похода · +30 XP'), findsOneWidget);
    expect(find.text('+90 XP пилота'), findsNothing);
    expect(find.text('Навигатор · +21 связи'), findsOneWidget);
    final Finder historyToggle = find.byKey(
      const Key('platform-journey-archive-3-history-toggle'),
    );
    await _bringIntoView(tester, historyToggle);
    expect(historyToggle, findsOneWidget);
    expect(
      find.bySemanticsLabel('Показать решения похода 3. Записей: 3'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('platform-journey-decision-signal-source-v1')),
      findsNothing,
    );

    await tester.tap(historyToggle);
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Скрыть решения похода 3'), findsOneWidget);
    expect(
      find.byKey(const Key('platform-journey-decision-signal-source-v1')),
      findsOneWidget,
    );
    final Finder firstArchivedDecision = find.byKey(
      const Key('platform-journey-decision-signal-source-v1'),
    );
    final String firstArchivedResolvedAt = _formattedDecisionTime(
      tester,
      firstArchivedDecision,
      '2026-07-26T05:50:00Z',
      russian: true,
    );
    expect(find.text(firstArchivedResolvedAt), findsOneWidget);
    expect(
      find.byKey(const Key('platform-journey-decision-echo-vault-v1')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Запись 1 из 3. Первый сигнал второго похода. '
        'Решение: Разобрать сигнал. Итог: Карта отклика. '
        'Первое решение сохранено. $firstArchivedResolvedAt. '
        'Награды: +20 XP пилота; '
        'Навигатор: +5 связи; +1 Эхо-нити.',
      ),
      findsOneWidget,
    );
    expect(find.text('Второе решение сохранено.'), findsOneWidget);
    expect(find.text('Навигатор · +9 связи'), findsOneWidget);

    await tester.tap(historyToggle);
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('Показать решения похода 3. Записей: 3'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('platform-journey-decision-signal-source-v1')),
      findsNothing,
    );
    final Finder previous = find.byKey(const Key('platform-journey-archive-2'));
    await _bringIntoView(tester, previous);
    expect(find.text('Поход №2'), findsOneWidget);
    expect(
      find.byKey(const Key('platform-journey-archive-2-time')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('platform-journey-archive-2-duration')),
      findsNothing,
    );
    expect(
      find.bySemanticsLabel(
        'Поход 2. Принято решений: 2. '
        'Итоговые награды: +60 XP пилота; +14 связи спутников.',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('platform-journey-archive-2-history')),
      findsNothing,
    );
    _expectNoLayoutException(tester);
    semantics.dispose();
  });

  testWidgets('archived decisions stay bounded at compact enlarged text', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final SemanticsHandle semantics = tester.ensureSemantics();
    const HomeExpeditionDecisionLogEntry decision =
        HomeExpeditionDecisionLogEntry(
          eventId: 'long-archive-event-v1',
          eventTitle: 'Сохранённое событие с очень длинным названием',
          choiceId: 'follow-saved-starlight',
          choiceTitle: 'Следовать по сохранённому звёздному коридору',
          outcomeTitle: 'Маршрут удержан вопреки нестабильному сигналу',
          outcomeSummary:
              'Спутник запомнил каждый поворот завершённого маршрута.',
          resolvedAt: '2026-07-26T06:02:00Z',
        );
    final HomeSnapshot home = _homeSnapshotWithDecisions(
      const <HomeExpeditionDecisionLogEntry>[],
      journeyNumber: 2,
      journeyChronicle: const HomeJourneyChronicle(
        completedJourneyCount: 123456,
        decisionCount: 987654,
        totalDurationSeconds: 65700,
        shortestDurationSeconds: 0,
        shortestJourneyNumber: 123455,
        shortestJourneyCompletedAt: '2026-07-25T05:01:00Z',
        longestDurationSeconds: 12600,
        longestJourneyNumber: 1,
        longestJourneyCompletedAt: '2026-07-26T06:02:00Z',
        averageDurationSeconds: 0,
        pilotExperienceGained: 123456789,
        petBondGained: 987654321,
        decisionOutcomes: <HomeJourneyDecisionOutcome>[
          HomeJourneyDecisionOutcome(
            eventId: 'long-archive-event-v1',
            eventTitle: 'Сохранённое событие с очень длинным названием',
            choiceId: 'follow-saved-starlight',
            choiceTitle: 'Следовать по сохранённому звёздному коридору',
            outcomeTitle: 'Маршрут удержан вопреки нестабильному сигналу',
            decisionCount: 987654,
          ),
        ],
        finaleOutcomes: <HomeJourneyFinaleOutcome>[
          HomeJourneyFinaleOutcome(
            eventId: 'long-archive-event-v1',
            eventTitle: 'Сохранённое событие с очень длинным названием',
            choiceId: 'follow-saved-starlight',
            choiceTitle: 'Следовать по сохранённому звёздному коридору',
            outcomeTitle: 'Маршрут удержан вопреки нестабильному сигналу',
            journeyCount: 123456,
          ),
        ],
      ),
      recentJourneyRecaps: const <HomeExpeditionCompletionRecap>[
        HomeExpeditionCompletionRecap(
          journeyNumber: 1,
          decisionCount: 1,
          decisions: <HomeExpeditionDecisionLogEntry>[decision],
          finalDecision: HomeJourneyFinalDecision(
            eventId: 'long-archive-event-v1',
            eventTitle: 'Сохранённое событие с очень длинным названием',
            choiceId: 'follow-saved-starlight',
            choiceTitle: 'Следовать по сохранённому звёздному коридору',
            outcomeTitle: 'Маршрут удержан вопреки нестабильному сигналу',
            outcomeSummary:
                'Спутник запомнил каждый поворот завершённого маршрута.',
            resolvedAt: '2026-07-26T06:02:00Z',
          ),
          durationSeconds: 3900,
          pilotExperienceGained: 0,
          petBondGained: 0,
          materials: <HomeJourneyMaterialReward>[],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        builder: (BuildContext context, Widget? child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          );
        },
        home: PlatformScreen(
          loader: () async => platformSnapshot(),
          homeLoader: () async => home,
          recordExperimentExposures: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder chronicle = find.byKey(
      const Key('platform-journey-chronicle'),
    );
    await _bringIntoView(tester, chronicle);
    final String recordCompletedAt = _formattedChronicleRecordTime(
      tester,
      chronicle,
      '2026-07-26T06:02:00Z',
      russian: true,
    );
    final String shortestCompletedAt = _formattedChronicleShortestTime(
      tester,
      chronicle,
      '2026-07-25T05:01:00Z',
      russian: true,
    );
    expect(chronicle, findsOneWidget);
    expect(find.text('Время в походах: 18 ч 15 мин'), findsOneWidget);
    expect(
      find.byKey(const Key('platform-journey-chronicle-duration')),
      findsOneWidget,
    );
    expect(
      find.text('Самый короткий поход №123455: меньше 1 мин'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('platform-journey-chronicle-shortest-duration')),
      findsOneWidget,
    );
    expect(find.text(shortestCompletedAt), findsOneWidget);
    expect(
      find.byKey(const Key('platform-journey-chronicle-shortest-completed-at')),
      findsOneWidget,
    );
    expect(find.text('Самый долгий поход №1: 3 ч 30 мин'), findsOneWidget);
    expect(
      find.byKey(const Key('platform-journey-chronicle-longest-duration')),
      findsOneWidget,
    );
    expect(find.text(recordCompletedAt), findsOneWidget);
    expect(
      find.byKey(const Key('platform-journey-chronicle-record-completed-at')),
      findsOneWidget,
    );
    expect(find.text('В среднем за поход: меньше 1 мин'), findsOneWidget);
    expect(
      find.byKey(const Key('platform-journey-chronicle-average-duration')),
      findsOneWidget,
    );
    expect(find.text('+123456789 XP пилота'), findsOneWidget);
    expect(find.text('Решения летописи'), findsOneWidget);
    expect(
      find.text(
        'Следовать по сохранённому звёздному коридору → '
        'Маршрут удержан вопреки нестабильному сигналу · ×987654',
      ),
      findsOneWidget,
    );
    expect(find.text('Финалы маршрутов'), findsOneWidget);
    expect(
      find.text(
        'Следовать по сохранённому звёздному коридору → '
        'Маршрут удержан вопреки нестабильному сигналу · ×123456',
      ),
      findsOneWidget,
    );
    _expectNoLayoutException(tester);

    final Finder toggle = find.byKey(
      const Key('platform-journey-archive-1-history-toggle'),
    );
    await _bringIntoView(tester, toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    final Finder entry = find.byKey(
      const Key('platform-journey-decision-long-archive-event-v1'),
    );
    await _bringIntoView(tester, entry);

    expect(entry, findsOneWidget);
    expect(
      find.byKey(const Key('platform-journey-archive-1-time')),
      findsOneWidget,
    );
    expect(find.text('Длительность: 1 ч 5 мин'), findsOneWidget);
    expect(
      find.byKey(const Key('platform-journey-archive-1-duration')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key('platform-journey-decision-long-archive-event-v1-time'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: entry, matching: find.text(decision.outcomeSummary)),
      findsOneWidget,
    );
    _expectNoLayoutException(tester);
    semantics.dispose();
  });

  testWidgets('journal shows an accessible empty decision state', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: PlatformScreen(
          loader: () async => platformSnapshot(),
          homeLoader: () async => HomeSnapshot.demo,
          recordExperimentExposures: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder card = find.byKey(const Key('platform-journey-decision-log'));
    await _bringIntoView(tester, card);

    expect(find.text('Решения маршрута'), findsOneWidget);
    expect(
      find.byKey(const Key('platform-current-journey-decision-count')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('platform-current-journey-latest-decision')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('platform-journey-completion-recap')),
      findsNothing,
    );
    expect(find.byKey(const Key('platform-journey-chronicle')), findsNothing);
    final Finder empty = find.byKey(
      const Key('platform-journey-decision-empty'),
    );
    await _bringIntoView(tester, empty);
    expect(
      find.text('Первое решение появится после события маршрута.'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Поход 1: решений пока нет'), findsOneWidget);
    _expectNoLayoutException(tester);
    semantics.dispose();
  });

  testWidgets('intermediate pet form keeps the adult evolution action', (
    WidgetTester tester,
  ) async {
    final PlatformSnapshot initial = platformSnapshot(
      sparkName: 'Искра-проводник',
      sparkLevel: 2,
      sparkBond: 140,
      sparkEvolutionStage: 1,
      sparkEvolutionBond: 140,
      sparkMaximumEvolutionStage: 2,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        home: PlatformScreen(
          loader: () async => initial,
          homeLoader: () async => HomeSnapshot.demo,
          recordExperimentExposures: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder evolve = find.byKey(const Key('platform-evolve-pet-spark-v1'));
    await _bringIntoView(tester, evolve);

    final FilledButton button = tester.widget<FilledButton>(evolve);
    expect(button.onPressed, isNotNull);
    expect(find.text('Эволюционировать'), findsOneWidget);
    expect(
      find.byKey(const Key('companion-bond-signal-spark-v1-spark-ready')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('companion-bond-signal-spark-v1-spark-evolved')),
      findsNothing,
    );
    expect(
      find.bySemanticsLabel('Рост спутника: Юный, этап 2 из 3'),
      findsWidgets,
    );
    expect(find.textContaining('для следующей эволюции'), findsNothing);
    _expectNoLayoutException(tester);
  });

  testWidgets('journal retries with a localized error and no stale actions', (
    WidgetTester tester,
  ) async {
    int attempts = 0;
    final Completer<PlatformSnapshot> firstLoad = Completer<PlatformSnapshot>();

    await tester.pumpWidget(
      MaterialApp(
        home: PlatformScreen(
          loader: () {
            attempts += 1;
            if (attempts == 1) {
              return firstLoad.future;
            }
            return Future<PlatformSnapshot>.value(platformSnapshot());
          },
          homeLoader: () async => HomeSnapshot.demo,
          recordExperimentExposures: false,
        ),
      ),
    );
    await tester.pump();
    firstLoad.completeError(
      const PlatformApiException(
        statusCode: 503,
        code: 'SERVICE_UNAVAILABLE',
        message: 'Backend недоступен',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('platform-error-state')), findsOneWidget);
    expect(find.byType(ExpeditionReadState), findsOneWidget);
    expect(find.byKey(const Key('platform-journal-hero')), findsNothing);
    expect(find.text('Не удалось загрузить путевой журнал'), findsOneWidget);
    expect(find.textContaining('Актуальные записи не приняты'), findsOneWidget);
    expect(find.textContaining('Backend недоступен'), findsNothing);

    await tester.tap(find.byKey(const Key('platform-error-retry')));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.byKey(const Key('platform-error-state')), findsNothing);
    expect(find.byKey(const Key('platform-journal-hero')), findsOneWidget);
  });

  testWidgets('uses the shared expedition language for the journal', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final PlatformSnapshot initial = platformSnapshot();
    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        home: PlatformScreen(
          loader: () async => initial,
          homeLoader: () async => HomeSnapshot.demo,
          recordExperimentExposures: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ExpeditionBackdrop), findsOneWidget);
    expect(find.byType(ExpeditionPanel), findsWidgets);
    expect(find.byType(ChapterVista), findsOneWidget);
    expect(find.byKey(const Key('platform-chapter-vista')), findsOneWidget);
    final ExpeditionPanel hero = tester.widget<ExpeditionPanel>(
      find.byKey(const Key('platform-journal-hero')),
    );
    expect(hero.tone, ExpeditionPanelTone.resonance);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      Colors.transparent,
    );
    expect(
      find.text(
        'Глава из ${initial.content.chapterNodes} узлов · '
        'состояние ${initial.stateVersion}',
      ),
      findsOneWidget,
    );

    final Finder firstJourney = find.byKey(
      const Key('first-journey-route-signal-1-6'),
    );
    await tester.scrollUntilVisible(
      firstJourney,
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(find.byType(FirstJourneyRouteSignal), findsOneWidget);
    expect(firstJourney, findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Первый путь: завершено 1 из 6 этапов. Осталось пройти 5 этапов',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Познакомиться с навигатором: завершено'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Разрешить чтение активности: не завершено'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('platform-advance-weekly')),
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(find.byType(WeeklyRouteSignal), findsOneWidget);
    expect(
      find.byKey(const Key('weekly-route-signal-weekly-route-1-firstSignal')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Недельный маршрут «Сезон первого сигнала»: 40 из 100 ENERGY',
      ),
      findsOneWidget,
    );
    expect(
      find.text('До награды уровня 3: ещё 80 сезонного XP'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('До награды уровня 3: ещё 80 сезонного XP'),
      findsOneWidget,
    );
    expect(find.text('Доступна 1 сезонная награда'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Доступна 1 сезонная награда'),
      findsOneWidget,
    );
    expect(find.byType(SeasonRewardSeal), findsOneWidget);
    expect(
      find.byKey(const Key('season-reward-seal-signal-season-1-2-firstSignal')),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('legacy season snapshot omits inferred reward guidance', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PlatformScreen(
          loader: () async => platformSnapshot(seasonXpPerLevel: null),
          homeLoader: () async => HomeSnapshot.demo,
          recordExperimentExposures: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('platform-advance-weekly')),
      300,
      scrollable: find.byType(Scrollable),
    );

    expect(find.textContaining('До награды уровня'), findsNothing);
    expect(find.textContaining('сезонная награда'), findsNothing);
    expect(
      find.byKey(const Key('season-reward-seal-signal-season-1-2-firstSignal')),
      findsOneWidget,
    );
  });

  testWidgets('keeps server progression copy beside exact visual identities', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final PlatformSnapshot initial = platformSnapshot(
      seasonXp: 40,
      achievements: const <String>['onboarding-complete'],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        home: PlatformScreen(
          loader: () async => initial,
          homeLoader: () async => HomeSnapshot.demo,
          recordExperimentExposures: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder unlockedSkill = find.byKey(
      const Key('progression-sigil-steady-step-active'),
    );
    await _bringIntoView(tester, unlockedSkill);
    expect(unlockedSkill, findsOneWidget);
    expect(find.text('Ровный шаг'), findsOneWidget);

    final Finder lockedSkill = find.byKey(
      const Key('progression-sigil-trail-memory-locked'),
    );
    await _bringIntoView(tester, lockedSkill);
    expect(lockedSkill, findsOneWidget);
    expect(find.byType(ProgressionSigil), findsWidgets);
    expect(
      find.byKey(const Key('platform-skill-wide-trail-memory')),
      findsOneWidget,
    );
    expect(
      find.textContaining('До открытия: ещё 60 сезонного XP'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('До открытия: ещё 60 сезонного XP')),
      findsOneWidget,
    );
    final IconButton unavailableSkillButton = tester.widget<IconButton>(
      find.byKey(const Key('platform-unlock-skill-trail-memory')),
    );
    expect(unavailableSkillButton.onPressed, isNull);

    final Finder stepsQuest = find.byKey(
      const Key('quest-route-signal-walk-3000-steps'),
    );
    await _bringIntoView(tester, stepsQuest);
    expect(stepsQuest, findsOneWidget);
    expect(find.byType(QuestRouteSignal), findsWidgets);
    expect(
      find.bySemanticsLabel('Прогресс задания «Первый маршрут»: 3000 из 3000'),
      findsOneWidget,
    );

    final Finder eventQuest = find.byKey(
      const Key('quest-route-signal-resolve-3-events'),
    );
    await _bringIntoView(tester, eventQuest);
    expect(eventQuest, findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Прогресс задания «Исследователь»: 2 из 3. '
        'До выполнения: ещё 1 событие',
      ),
      findsOneWidget,
    );
    expect(find.text('До выполнения: ещё 1 событие'), findsOneWidget);

    final Finder unlockedAchievement = find.byKey(
      const Key('platform-achievement-onboarding-complete'),
    );
    await _bringIntoView(tester, unlockedAchievement);
    expect(
      find.bySemanticsLabel('1 из 2 открыто. Осталось открыть 1 достижение'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Достижение «Путь открыт»: открыто'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('progression-sigil-onboarding-complete-active')),
      findsOneWidget,
    );

    final Finder lockedAchievement = find.byKey(
      const Key('platform-achievement-season-level-3'),
    );
    await _bringIntoView(tester, lockedAchievement);
    expect(
      find.bySemanticsLabel('Достижение «Третий уровень сезона»: закрыто'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('full journal supports compact enlarged text without overflow', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final SemanticsHandle semantics = tester.ensureSemantics();
    int loads = 0;
    bool accountOpened = false;
    bool recoveryOpened = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        builder: (BuildContext context, Widget? child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          );
        },
        home: MainNavigationShell(
          home: const SizedBox.expand(),
          platform: PlatformScreen(
            loader: () async {
              loads += 1;
              return platformSnapshot();
            },
            homeLoader: () async => HomeSnapshot.demo,
            recordExperimentExposures: false,
            recoveryCount: 2,
            onOpenRecovery: () {
              recoveryOpened = true;
            },
            onOpenAccount: () {
              accountOpened = true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('navigation-platform')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('platform-more-actions')), findsOneWidget);
    expect(find.byTooltip('Обновить'), findsNothing);
    expect(find.byTooltip('Аккаунт'), findsNothing);
    _expectNoLayoutException(tester);

    await tester.tap(find.byKey(const Key('platform-command-recovery')));
    expect(recoveryOpened, isTrue);

    await tester.tap(find.byKey(const Key('platform-more-actions')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('platform-menu-refresh')));
    await tester.pumpAndSettle();
    expect(loads, 2);

    await tester.tap(find.byKey(const Key('platform-more-actions')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('platform-menu-account')));
    await tester.pump();
    expect(accountOpened, isTrue);

    for (final Key key in const <Key>[
      Key('platform-onboarding-compact'),
      Key('first-journey-route-signal-1-6'),
      Key('platform-weekly-route-compact'),
      Key('weekly-route-signal-weekly-route-1-firstSignal'),
      Key('season-reward-seal-signal-season-1-2-firstSignal'),
      Key('platform-evolvable-companions'),
      Key('platform-pet-compact-spark-v1'),
      Key('platform-pet-compact-moss-v1'),
      Key('platform-skills-collection-summary'),
      Key('platform-unlockable-skills'),
      Key('platform-skill-compact-steady-step'),
      Key('platform-skill-compact-trail-memory'),
      Key('platform-claimable-quest-rewards'),
      Key('platform-quest-compact-walk-3000'),
      Key('quest-route-signal-walk-3000-steps'),
      Key('platform-squad-empty-compact'),
      Key('squad-formation-signal-open-0'),
      Key('platform-cosmetics-collection-summary'),
      Key('platform-cosmetic-compact-pilot-scarf'),
      Key('platform-achievement-onboarding-complete'),
      Key('platform-journal-footer'),
    ]) {
      final Finder target = find.byKey(key);
      await _bringIntoView(tester, target);
      expect(target, findsOneWidget);
      _expectNoLayoutException(tester);
      if (key == const Key('platform-cosmetics-collection-summary')) {
        expect(
          find.text('1 из 2 в коллекции · До полной коллекции: 1 образ'),
          findsOneWidget,
        );
      }
      if (key == const Key('platform-evolvable-companions')) {
        expect(find.text('К эволюции готов 1 питомец'), findsOneWidget);
      }
      if (key == const Key('platform-skills-collection-summary')) {
        expect(
          find.text('Открыто навыков: 1 из 2 · До полной коллекции: 1 навык'),
          findsOneWidget,
        );
      }
      if (key == const Key('platform-unlockable-skills')) {
        expect(find.text('Можно открыть 1 навык'), findsOneWidget);
      }
      if (key == const Key('platform-claimable-quest-rewards')) {
        expect(find.text('Доступна 1 награда за задание'), findsOneWidget);
      }
      if (key == const Key('platform-pet-compact-moss-v1')) {
        expect(
          find.text('До следующей эволюции: ещё 33 связи'),
          findsOneWidget,
        );
      }
      if (key == const Key('platform-weekly-route-compact')) {
        expect(
          find.text('До награды уровня 3: ещё 80 сезонного XP'),
          findsOneWidget,
        );
      }
      if (key == const Key('platform-skill-compact-steady-step')) {
        expect(find.text('НАВЫК ОТКРЫТ'), findsOneWidget);
      }
      if (key == const Key('platform-skill-compact-trail-memory')) {
        expect(find.text('Нужно 100 сезонного XP'), findsOneWidget);
        final OutlinedButton readySkillButton = tester.widget<OutlinedButton>(
          find.byKey(const Key('platform-unlock-skill-trail-memory')),
        );
        expect(readySkillButton.onPressed, isNotNull);
      }
    }

    final Finder journalScrollable = find.descendant(
      of: find.byKey(const Key('platform-screen-list')),
      matching: find.byType(Scrollable),
    );
    final ScrollableState scrollable = tester.state<ScrollableState>(
      journalScrollable,
    );
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pump();

    final double footerBottom = tester
        .getBottomRight(find.byKey(const Key('platform-journal-footer')))
        .dy;
    final double navigationTop = tester
        .getTopLeft(find.byType(NavigationBar))
        .dy;
    expect(footerBottom, lessThan(navigationTop));
    _expectNoLayoutException(tester);
    semantics.dispose();
  });

  testWidgets('renders platform snapshot and resumes guided first journey', (
    WidgetTester tester,
  ) async {
    final PlatformSnapshot initial = platformSnapshot();
    int resumes = 0;
    bool recoveryOpened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: PlatformScreen(
          loader: () async => initial,
          homeLoader: () async => HomeSnapshot.demo,
          recordExperimentExposures: false,
          recoveryUnavailable: true,
          onOpenRecovery: () {
            recoveryOpened = true;
          },
          onResumeFirstJourney: () {
            resumes += 1;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('platform-command-recovery')));
    expect(recoveryOpened, isTrue);
    expect(find.text('Путевой журнал'), findsOneWidget);
    expect(find.text('Сезон первого сигнала'), findsWidgets);

    final Finder firstJourney = find.byKey(
      const Key('first-journey-route-signal-1-6'),
    );
    await _bringIntoView(tester, firstJourney);
    expect(find.text('1/6'), findsOneWidget);

    final Finder resume = find.byKey(
      const Key('platform-resume-first-journey'),
    );
    await _bringIntoView(tester, resume);
    await tester.tap(resume);
    await tester.pumpAndSettle();

    expect(resumes, 1);
    await tester.scrollUntilVisible(
      find.text('Искра · уровень 1'),
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Искра · уровень 1'), findsOneWidget);
    expect(find.byType(CompanionPortrait), findsWidgets);
    expect(
      find.byKey(const Key('platform-pet-portrait-spark-v1')),
      findsOneWidget,
    );
  });

  testWidgets('keeps onboarding counts tied to the accepted step list', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final PlatformSnapshot initial = platformSnapshot(
      completedOnboardingSteps: const <String>['welcome', 'retired-step'],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        home: PlatformScreen(
          loader: () async => initial,
          homeLoader: () async => HomeSnapshot.demo,
          recordExperimentExposures: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder firstJourney = find.byKey(
      const Key('first-journey-route-signal-1-6'),
    );
    await tester.scrollUntilVisible(
      firstJourney,
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(firstJourney, findsOneWidget);
    expect(find.text('1/6'), findsOneWidget);
    expect(find.text('2/6'), findsNothing);
    expect(find.text('Осталось пройти 5 этапов'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Первый путь: завершено 1 из 6 этапов. Осталось пройти 5 этапов',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('authoritative generation reloads journal without losing input', (
    WidgetTester tester,
  ) async {
    int generation = 0;
    int loads = 0;
    late StateSetter setHostState;
    Future<PlatformSnapshot> loader() async {
      loads += 1;
      return platformSnapshot();
    }

    Future<HomeSnapshot> homeLoader() async => HomeSnapshot.demo;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            setHostState = setState;
            return PlatformScreen(
              loader: loader,
              homeLoader: homeLoader,
              recordExperimentExposures: false,
              authoritativeRefreshGeneration: generation,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final Finder squadName = find.byKey(const Key('platform-squad-name'));
    await tester.scrollUntilVisible(
      squadName,
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.enterText(squadName, 'Сохранённый отряд');
    await tester.pump();
    expect(loads, 1);

    setHostState(() {
      generation += 1;
    });
    await tester.pumpAndSettle();

    expect(loads, 2);
    await tester.scrollUntilVisible(
      find.byKey(const Key('platform-squad-name'), skipOffstage: false),
      300,
      scrollable: find.byType(Scrollable),
    );
    final TextField refreshedSquadName = tester.widget<TextField>(
      find.byKey(const Key('platform-squad-name'), skipOffstage: false),
    );
    expect(refreshedSquadName.controller?.text, 'Сохранённый отряд');
  });

  testWidgets('enables squad actions when text is entered', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PlatformScreen(
          loader: () async => platformSnapshot(),
          homeLoader: () async => HomeSnapshot.demo,
          recordExperimentExposures: false,
          commandExecutor:
              ({
                required String commandType,
                required Map<String, Object?> payload,
                required String idempotencyKey,
              }) async => platformCommandResult(
                commandType: commandType,
                idempotencyKey: idempotencyKey,
                snapshot: platformSnapshot(),
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder squadName = find.byKey(const Key('platform-squad-name'));
    await tester.scrollUntilVisible(
      squadName,
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.enterText(squadName, 'Первые ходоки');
    await tester.pump();

    final FilledButton create = tester.widget<FilledButton>(
      find.byKey(const Key('platform-create-squad')),
    );
    expect(create.onPressed, isNotNull);

    final Finder squadId = find.byKey(const Key('platform-squad-id'));
    await tester.enterText(squadId, '11111111-1111-1111-1111-111111111111');
    await tester.pump();

    final OutlinedButton join = tester.widget<OutlinedButton>(
      find.byKey(const Key('platform-join-squad')),
    );
    expect(join.onPressed, isNotNull);
  });

  testWidgets('renders only the authoritative squad formation summary', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const String squadId = '11111111-1111-1111-1111-111111111111';
    final SemanticsHandle semantics = tester.ensureSemantics();
    final PlatformSnapshot snapshot = platformSnapshot(
      squad: <String, dynamic>{
        'squadId': squadId,
        'name': 'Северный импульс',
        'ownerUserId': 'pilot-owner',
        'memberUserIds': <String>[
          'pilot-owner',
          'pilot-member-1',
          'pilot-member-2',
          'pilot-member-3',
          'pilot-member-4',
          'pilot-member-5',
          'pilot-member-6',
        ],
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        builder: (BuildContext context, Widget? child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          );
        },
        home: PlatformScreen(
          loader: () async => snapshot,
          homeLoader: () async => HomeSnapshot.demo,
          recordExperimentExposures: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder summary = find.byKey(const Key('platform-squad-summary'));
    await _bringIntoView(tester, summary);

    expect(summary, findsOneWidget);
    expect(find.byType(SquadFormationSignal), findsOneWidget);
    expect(
      find.byKey(const Key('platform-squad-connected-compact')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('squad-formation-signal-connected-6-overflow')),
      findsOneWidget,
    );
    expect(find.text('Северный импульс'), findsOneWidget);
    expect(find.text('УЧАСТНИКОВ: 7'), findsOneWidget);
    expect(find.text('ID: $squadId'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Отряд «Северный импульс». Участников: 7'),
      findsOneWidget,
    );
    expect(find.text('pilot-member-1'), findsNothing);
    expect(find.byKey(const Key('platform-squad-name')), findsNothing);
    final OutlinedButton leave = tester.widget<OutlinedButton>(
      find.byKey(const Key('platform-leave-squad')),
    );
    expect(leave.onPressed, isNotNull);
    _expectNoLayoutException(tester);
    semantics.dispose();
  });

  testWidgets('shows localized command failure without backend diagnostics', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PlatformScreen(
          loader: () async => platformSnapshot(),
          homeLoader: () async => HomeSnapshot.demo,
          recordExperimentExposures: false,
          commandExecutor:
              ({
                required String commandType,
                required Map<String, Object?> payload,
                required String idempotencyKey,
              }) async => throw const PlatformApiException(
                statusCode: 409,
                code: 'PLATFORM_STATE_CONFLICT',
                message: 'Недостаточно сезонного опыта',
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder selectPet = find.byKey(
      const Key('platform-select-pet-moss-v1'),
    );
    await _bringIntoView(tester, selectPet);
    await tester.tap(selectPet);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Не удалось выполнить действие. Обновите журнал и повторите попытку.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Недостаточно сезонного опыта'), findsNothing);
  });

  testWidgets('cached journal is read-only and does not guess ENERGY balance', (
    WidgetTester tester,
  ) async {
    int commands = 0;
    final PlatformSnapshot cached = platformSnapshot(
      cacheMetadata: CachedReadMetadata(
        cachedAt: DateTime.utc(2026, 7, 27, 9),
        reason: 'Нет соединения с сервером',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PlatformScreen(
          loader: () async => cached,
          homeLoader: () async => HomeSnapshot.demo,
          recordExperimentExposures: false,
          commandExecutor:
              ({
                required String commandType,
                required Map<String, Object?> payload,
                required String idempotencyKey,
              }) async {
                commands += 1;
                return platformCommandResult(
                  commandType: commandType,
                  idempotencyKey: idempotencyKey,
                  snapshot: cached,
                );
              },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cached-snapshot-banner')), findsOneWidget);
    final Finder resume = find.byKey(
      const Key('platform-resume-first-journey'),
    );
    await _bringIntoView(tester, resume);
    final FilledButton resumeButton = tester.widget<FilledButton>(resume);
    expect(resumeButton.onPressed, isNull);

    final Finder weekly = find.byKey(const Key('platform-advance-weekly'));
    await tester.scrollUntilVisible(
      weekly,
      300,
      scrollable: find.byType(Scrollable),
    );
    final FilledButton weeklyButton = tester.widget<FilledButton>(weekly);
    expect(weeklyButton.onPressed, isNull);
    expect(find.text('Баланс ENERGY сейчас недоступен'), findsOneWidget);
    expect(commands, 0);

    await tester.scrollUntilVisible(
      find.text('Косметика'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const Key('platform-buy-cosmetic-spark-halo')),
      findsNothing,
    );
    expect(_sandboxText(), findsNothing);

    final Finder refreshFinder = find.widgetWithText(
      OutlinedButton,
      'Обновить журнал',
    );
    await tester.scrollUntilVisible(
      refreshFinder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final OutlinedButton refresh = tester.widget<OutlinedButton>(refreshFinder);
    expect(refresh.onPressed, isNotNull);
  });

  testWidgets('journal distinguishes the pilot from Navigator companion', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final PlatformSnapshot snapshot = platformSnapshot(
      activePetId: 'rune-v1',
      ownedCosmetics: const <String>[],
      activeCosmeticId: null,
      equippedCosmetics: const <String, String>{},
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        home: PlatformScreen(
          loader: () async => snapshot,
          homeLoader: () async => HomeSnapshot.demo,
          recordExperimentExposures: false,
          sandboxPaymentsSupported: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Пилот и Навигатор'), findsOneWidget);
    expect(find.text('Навигатор и Навигатор'), findsNothing);
    expect(
      find.bySemanticsLabel(
        'Экипаж маршрута: пилот и Навигатор. Без активной косметики',
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('journal renders equipped character cosmetics and previews', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final PlatformSnapshot snapshot = platformSnapshot(
      ownedCosmetics: const <String>['pilot-scarf', 'spark-halo'],
      activeCosmeticId: CharacterCosmeticIds.sparkHalo,
      equippedCosmetics: const <String, String>{
        'PILOT': CharacterCosmeticIds.pilotScarf,
        'PET': CharacterCosmeticIds.sparkHalo,
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        home: PlatformScreen(
          loader: () async => snapshot,
          homeLoader: () async => HomeSnapshot.demo,
          recordExperimentExposures: false,
          sandboxPaymentsSupported: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final PilotPortrait equippedPilot = tester.widget<PilotPortrait>(
      find.byKey(const Key('platform-hero-pilot-portrait')),
    );
    final CompanionPortrait equippedHeroPet = tester.widget<CompanionPortrait>(
      find.byKey(const Key('platform-hero-pet-portrait')),
    );
    expect(equippedPilot.hasNavigatorScarf, isTrue);
    expect(equippedHeroPet.hasSparkHalo, isTrue);
    expect(
      find.bySemanticsLabel(
        'Экипаж маршрута: пилот и Искра. '
        'Экипировано: Шарф навигатора, Ореол Искры',
      ),
      findsOneWidget,
    );

    final Finder equippedSparkFinder = find.byKey(
      const Key('platform-pet-portrait-spark-v1'),
    );
    await _bringIntoView(tester, equippedSparkFinder);
    final CompanionPortrait equippedSpark = tester.widget<CompanionPortrait>(
      equippedSparkFinder,
    );
    expect(equippedSpark.safeEvolutionStage, 0);
    expect(
      equippedSpark.illustrationAsset,
      'assets/characters/companion_spark_stage0.webp',
    );
    expect(equippedSpark.hasSparkHalo, isTrue);
    expect(
      find.byKey(const Key('platform-pet-growth-spark-v1')),
      findsOneWidget,
    );
    expect(find.byType(CompanionGrowthTrack), findsWidgets);
    expect(find.byType(CompanionBondSignal), findsWidgets);
    expect(
      find.byKey(const Key('companion-bond-signal-spark-v1-spark-ready')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('companion-bond-signal-moss-v1-moss-growing')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Связь спутника «Искра»: 50 из 50. '
        'Готова к эволюции',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Связь спутника «Мох»: 12 из 45. '
        'До следующей эволюции: ещё 33 связи',
      ),
      findsOneWidget,
    );
    expect(find.text('До следующей эволюции: ещё 33 связи'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(
      find.bySemanticsLabel('Рост спутника: Малыш, этап 1 из 3'),
      findsWidgets,
    );
    expect(
      find.bySemanticsLabel(
        RegExp(
          'Искра, люмин, Малыш · форма 1, '
          'активный спутник, Ореол Искры',
        ),
      ),
      findsOneWidget,
    );

    final Finder pilotPreview = find.byKey(
      const Key('platform-cosmetic-preview-pilot-scarf'),
    );
    await _bringIntoView(tester, pilotPreview);
    final PilotMotionPortrait scarf = tester.widget<PilotMotionPortrait>(
      pilotPreview,
    );
    expect(scarf.hasNavigatorScarf, isTrue);
    expect(scarf.hasMotionAsset, isTrue);
    expect(
      scarf.motionAssetPath,
      PilotMotionPortrait.navigatorScarfMotionAssetPath,
    );
    expect(
      find.byKey(const Key('platform-equipped-cosmetic-pilot-scarf')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('platform-equip-cosmetic-pilot-scarf')),
      findsNothing,
    );

    final Finder sparkPreview = find.byKey(
      const Key('platform-cosmetic-preview-spark-halo'),
    );
    await _bringIntoView(tester, sparkPreview);
    final CompanionPortrait halo = tester.widget<CompanionPortrait>(
      sparkPreview,
    );
    expect(halo.hasSparkHalo, isTrue);
    expect(find.text('Спутник'), findsOneWidget);
    expect(
      find.byKey(const Key('platform-equipped-cosmetic-spark-halo')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('platform-equip-cosmetic-spark-halo')),
      findsNothing,
    );
    expect(
      find.bySemanticsLabel('Пилот Навигатор, Шарф навигатора'),
      findsNothing,
    );
    _expectNoLayoutException(tester);

    semantics.dispose();
  });

  testWidgets(
    'journal applies exact profile cosmetic and keeps compact previews readable',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final SemanticsHandle semantics = tester.ensureSemantics();
      final PlatformSnapshot snapshot = platformSnapshot(
        ownedCosmetics: const <String>[
          'pilot-scarf',
          ProfileCosmeticIds.trailBanner,
          ProfileCosmeticIds.dawnFrame,
        ],
        equippedCosmetics: const <String, String>{
          'PILOT': CharacterCosmeticIds.pilotScarf,
          'PROFILE': ProfileCosmeticIds.dawnFrame,
        },
        includeProfileCosmetics: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: WalkingRpgTheme.dark(),
          builder: (BuildContext context, Widget? child) {
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.6)),
              child: child!,
            );
          },
          home: PlatformScreen(
            loader: () async => snapshot,
            homeLoader: () async => HomeSnapshot.demo,
            recordExperimentExposures: false,
            sandboxPaymentsSupported: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ProfileCosmeticFrame frame = tester.widget<ProfileCosmeticFrame>(
        find.byKey(const Key('platform-profile-cosmetic-frame')),
      );
      expect(frame.cosmeticId, ProfileCosmeticIds.dawnFrame);
      expect(
        find.byKey(const Key('profile-cosmetic-frame-dawn-frame')),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const Key('platform-chapter-vista')),
      );
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('Туманный сектор, визуальный образ первой главы'),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const Key('platform-journal-crew')),
      );
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel(
          'Экипаж маршрута: пилот и Искра. '
          'Экипировано: Шарф навигатора, Рамка рассвета',
        ),
        findsOneWidget,
      );

      for (final String cosmeticId in const <String>[
        ProfileCosmeticIds.trailBanner,
        ProfileCosmeticIds.dawnFrame,
      ]) {
        final Finder preview = find.byKey(
          Key('platform-cosmetic-preview-$cosmeticId'),
        );
        await _bringIntoView(tester, preview);
        expect(
          tester.widget<ProfileCosmeticPreview>(preview).cosmeticId,
          cosmeticId,
        );
        expect(
          find.byKey(Key('profile-cosmetic-preview-$cosmeticId')),
          findsOneWidget,
        );
        if (cosmeticId == ProfileCosmeticIds.trailBanner) {
          expect(
            find.byKey(const Key('platform-equip-cosmetic-trail-banner')),
            findsOneWidget,
          );
        } else {
          expect(
            find.byKey(const Key('platform-equipped-cosmetic-dawn-frame')),
            findsOneWidget,
          );
        }
        _expectNoLayoutException(tester);
      }
      semantics.dispose();
    },
  );

  testWidgets('journal applies legacy profile cosmetic pointer', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final Map<String, dynamic> json = platformSnapshotJson(
      ownedCosmetics: const <String>[ProfileCosmeticIds.dawnFrame],
      activeCosmeticId: ProfileCosmeticIds.dawnFrame,
      includeProfileCosmetics: true,
    );
    final Map<String, dynamic> userState = Map<String, dynamic>.from(
      json['userState']! as Map<String, dynamic>,
    )..remove('equippedCosmetics');
    json['userState'] = userState;
    final PlatformSnapshot snapshot = PlatformSnapshot.fromJson(json);

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        home: PlatformScreen(
          loader: () async => snapshot,
          homeLoader: () async => HomeSnapshot.demo,
          recordExperimentExposures: false,
          sandboxPaymentsSupported: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final ProfileCosmeticFrame frame = tester.widget<ProfileCosmeticFrame>(
      find.byKey(const Key('platform-profile-cosmetic-frame')),
    );
    expect(frame.cosmeticId, ProfileCosmeticIds.dawnFrame);
    expect(
      find.byKey(const Key('profile-cosmetic-frame-dawn-frame')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Экипаж маршрута: пилот и Искра. '
        'Экипировано: Рамка рассвета',
      ),
      findsOneWidget,
    );
    _expectNoLayoutException(tester);
    semantics.dispose();
  });

  testWidgets('fresh journal disables weekly spend when home is unavailable', (
    WidgetTester tester,
  ) async {
    int commands = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: PlatformScreen(
          loader: () async => platformSnapshot(),
          homeLoader: () async => throw StateError('home unavailable'),
          recordExperimentExposures: false,
          commandExecutor:
              ({
                required String commandType,
                required Map<String, Object?> payload,
                required String idempotencyKey,
              }) async {
                commands += 1;
                return platformCommandResult(
                  commandType: commandType,
                  idempotencyKey: idempotencyKey,
                  snapshot: platformSnapshot(),
                );
              },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder weekly = find.byKey(const Key('platform-advance-weekly'));
    await tester.scrollUntilVisible(
      weekly,
      300,
      scrollable: find.byType(Scrollable),
    );
    final FilledButton weeklyButton = tester.widget<FilledButton>(weekly);
    expect(weeklyButton.onPressed, isNull);
    expect(find.text('Баланс ENERGY сейчас недоступен'), findsOneWidget);
    expect(find.text('Потратить 10 ENERGY'), findsNothing);
    expect(
      find.byKey(const Key('platform-journey-decision-log')),
      findsNothing,
    );
    expect(commands, 0);
  });

  testWidgets('fresh enabled journal submits sandbox purchase', (
    WidgetTester tester,
  ) async {
    final List<String> commands = <String>[];
    final PlatformSnapshot snapshot = platformSnapshot();

    await tester.pumpWidget(
      MaterialApp(
        home: PlatformScreen(
          loader: () async => snapshot,
          homeLoader: () async => HomeSnapshot.demo,
          recordExperimentExposures: false,
          sandboxPaymentsSupported: true,
          commandExecutor:
              ({
                required String commandType,
                required Map<String, Object?> payload,
                required String idempotencyKey,
              }) async {
                commands.add(commandType);
                return platformCommandResult(
                  commandType: commandType,
                  idempotencyKey: idempotencyKey,
                  snapshot: snapshot,
                );
              },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder buy = find.byKey(
      const Key('platform-buy-cosmetic-spark-halo'),
    );
    await _bringIntoView(tester, buy);

    expect(_sandboxText(), findsWidgets);
    await tester.tap(buy);
    await tester.pumpAndSettle();

    expect(commands, <String>['BUY_COSMETIC']);
  });

  testWidgets(
    'accepted command snapshot keeps sandbox disabled after a stale reload',
    (WidgetTester tester) async {
      final PlatformSnapshot initial = platformSnapshot(stateVersion: 40);
      final PlatformSnapshot staleEnabled = platformSnapshot(stateVersion: 41);
      final PlatformSnapshot acceptedDisabled = platformSnapshot(
        stateVersion: 42,
        sandboxPaymentsEnabled: false,
      );
      final Completer<PlatformSnapshot> staleLoad =
          Completer<PlatformSnapshot>();
      final Completer<PlatformCommandResult> acceptedCommand =
          Completer<PlatformCommandResult>();
      final List<String> commands = <String>[];
      int generation = 0;
      int loads = 0;
      late StateSetter setHostState;

      Future<PlatformSnapshot> loader() {
        loads += 1;
        return loads == 1
            ? Future<PlatformSnapshot>.value(initial)
            : staleLoad.future;
      }

      Future<HomeSnapshot> homeLoader() async => HomeSnapshot.demo;

      Future<PlatformCommandResult> commandExecutor({
        required String commandType,
        required Map<String, Object?> payload,
        required String idempotencyKey,
      }) {
        commands.add(commandType);
        if (commands.length == 1) {
          return acceptedCommand.future;
        }
        return Future<PlatformCommandResult>.value(
          platformCommandResult(
            commandType: commandType,
            idempotencyKey: idempotencyKey,
            snapshot: acceptedDisabled,
          ),
        );
      }

      final PlatformSnapshotLoader stableLoader = loader;
      final PlatformHomeLoader stableHomeLoader = homeLoader;
      final PlatformCommandExecutor stableCommandExecutor = commandExecutor;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              setHostState = setState;
              return PlatformScreen(
                loader: stableLoader,
                homeLoader: stableHomeLoader,
                recordExperimentExposures: false,
                authoritativeRefreshGeneration: generation,
                sandboxPaymentsSupported: true,
                commandExecutor: stableCommandExecutor,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Finder buy = find.byKey(
        const Key('platform-buy-cosmetic-spark-halo'),
      );
      await tester.scrollUntilVisible(
        buy,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      final VoidCallback retainedPurchaseCallback = tester
          .widget<FilledButton>(buy)
          .onPressed!;

      retainedPurchaseCallback();
      await tester.pump();
      expect(commands, <String>['BUY_COSMETIC']);

      setHostState(() {
        generation += 1;
      });
      await tester.pump();
      expect(loads, 2);

      acceptedCommand.complete(
        platformCommandResult(
          commandType: 'BUY_COSMETIC',
          idempotencyKey: 'accepted-command',
          snapshot: acceptedDisabled,
        ),
      );
      await tester.pumpAndSettle();

      staleLoad.complete(staleEnabled);
      await tester.pump();
      setHostState(() {});
      await tester.pumpAndSettle();

      expect(loads, 2);
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pump();
      expect(find.text('Глава из 18 узлов · состояние 42'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Косметика'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.byKey(const Key('platform-buy-cosmetic-spark-halo')),
        findsNothing,
      );
      expect(_sandboxText(), findsNothing);

      retainedPurchaseCallback();
      await tester.pumpAndSettle();
      expect(commands, <String>['BUY_COSMETIC']);
    },
  );

  testWidgets(
    'sandbox-disabled journal hides purchase UI but keeps owned equip action',
    (WidgetTester tester) async {
      final List<String> commands = <String>[];
      final PlatformSnapshot snapshot = platformSnapshot(
        ownedCosmetics: const <String>['pilot-scarf', 'spark-halo'],
        sandboxPaymentsEnabled: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PlatformScreen(
            loader: () async => snapshot,
            homeLoader: () async => HomeSnapshot.demo,
            recordExperimentExposures: false,
            sandboxPaymentsSupported: true,
            commandExecutor:
                ({
                  required String commandType,
                  required Map<String, Object?> payload,
                  required String idempotencyKey,
                }) async {
                  commands.add(commandType);
                  return platformCommandResult(
                    commandType: commandType,
                    idempotencyKey: idempotencyKey,
                    snapshot: snapshot,
                  );
                },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Finder unavailable = find.text('Покупки сейчас недоступны.');
      await _bringIntoView(tester, unavailable);
      expect(unavailable, findsOneWidget);
      expect(_sandboxText(), findsNothing);

      final Finder equip = find.byKey(
        const Key('platform-equip-cosmetic-spark-halo'),
      );
      await _bringIntoView(tester, equip);

      expect(
        find.byKey(const Key('platform-buy-cosmetic-spark-halo')),
        findsNothing,
      );
      await tester.tap(equip);
      await tester.pumpAndSettle();

      expect(commands, <String>['EQUIP_COSMETIC']);
    },
  );

  testWidgets(
    'release capability hides purchase UI and rejects a stale callback',
    (WidgetTester tester) async {
      final PlatformSnapshot snapshot = platformSnapshot();
      final List<String> commands = <String>[];
      bool sandboxPaymentsSupported = true;
      late StateSetter setHostState;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              setHostState = setState;
              return PlatformScreen(
                loader: () async => snapshot,
                homeLoader: () async => HomeSnapshot.demo,
                recordExperimentExposures: false,
                sandboxPaymentsSupported: sandboxPaymentsSupported,
                commandExecutor:
                    ({
                      required String commandType,
                      required Map<String, Object?> payload,
                      required String idempotencyKey,
                    }) async {
                      commands.add(commandType);
                      return platformCommandResult(
                        commandType: commandType,
                        idempotencyKey: idempotencyKey,
                        snapshot: snapshot,
                      );
                    },
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Finder buy = find.byKey(
        const Key('platform-buy-cosmetic-spark-halo'),
      );
      await tester.scrollUntilVisible(
        buy,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      final VoidCallback stalePurchaseCallback = tester
          .widget<FilledButton>(buy)
          .onPressed!;

      setHostState(() {
        sandboxPaymentsSupported = false;
      });
      await tester.pumpAndSettle();
      stalePurchaseCallback();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Ореол Искры'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(
        find.byKey(const Key('platform-buy-cosmetic-spark-halo')),
        findsNothing,
      );
      expect(find.text('Ореол Искры'), findsOneWidget);
      expect(_sandboxText(), findsNothing);
      expect(commands, isEmpty);
    },
  );
}

Finder _sandboxText() {
  return find.textContaining(
    RegExp('sandbox', caseSensitive: false),
    findRichText: true,
  );
}

HomeSnapshot _homeSnapshotWithDecisions(
  List<HomeExpeditionDecisionLogEntry> decisions, {
  required int journeyNumber,
  String? expeditionStatus,
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
    expeditionStatus: expeditionStatus ?? demo.expeditionStatus,
    expeditionVersion: demo.expeditionVersion,
    expeditionJourneyNumber: journeyNumber,
    routeTrail: demo.routeTrail,
    decisionLog: decisions,
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

String _formattedChronicleRecordTime(
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
  return russian
      ? 'Рекорд установлен $date в $time'
      : 'Record set on $date at $time';
}

String _formattedChronicleShortestTime(
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
  return russian
      ? 'Самый короткий поход завершён $date в $time'
      : 'Shortest journey completed on $date at $time';
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

void _expectNoLayoutException(WidgetTester tester) {
  final Object? exception = tester.takeException();
  if (exception == null) {
    return;
  }
  fail(
    exception is FlutterError ? exception.toStringDeep() : exception.toString(),
  );
}
