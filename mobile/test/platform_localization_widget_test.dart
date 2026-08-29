import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/core/localization/current_platform_content_localizations.dart';
import 'package:walking_rpg_mobile/design_system/companion_portrait.dart';
import 'package:walking_rpg_mobile/design_system/expedition_event_scene.dart';
import 'package:walking_rpg_mobile/design_system/expedition_node_signal.dart';
import 'package:walking_rpg_mobile/design_system/expedition_progress_signal.dart';
import 'package:walking_rpg_mobile/design_system/expedition_route_trail.dart';
import 'package:walking_rpg_mobile/design_system/pilot_portrait.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';
import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';
import 'package:walking_rpg_mobile/features/platform/domain/platform_command_result.dart';
import 'package:walking_rpg_mobile/features/platform/domain/platform_snapshot.dart';
import 'package:walking_rpg_mobile/features/platform/presentation/platform_screen.dart';
import 'package:walking_rpg_mobile/l10n/generated/app_localizations.dart';
import 'package:walking_rpg_mobile/l10n/generated/app_localizations_en.dart';
import 'package:walking_rpg_mobile/l10n/generated/app_localizations_ru.dart';

import 'support/platform_fixture.dart';

typedef _ReadyChoiceLocaleSample = ({
  String futureDescription,
  String futureRequirement,
  String futureReward,
  String futureTitle,
  String knownDescription,
  String knownRequirement,
  String knownReward,
  String knownTitle,
  Locale locale,
  String lockedRequirement,
  String lockedReward,
  String lockedTitle,
});

typedef _JourneyLocaleSample = ({
  String energyLabel,
  String expectedLabel,
  String expeditionId,
  Locale locale,
  String serverName,
});

typedef _EventSceneLocaleSample = ({
  String eventLabel,
  String fallbackLabel,
  Locale locale,
  String sceneLabel,
  String summaryLabel,
  String title,
});

typedef _CompanionLocaleSample = ({
  String expectedLabel,
  bool legacyId,
  Locale locale,
  String? petId,
  String serverName,
});

typedef _CompanionProgressLocaleSample = ({
  String expectedLabel,
  Locale locale,
});

typedef _CompanionFormLocaleSample = ({
  String? expectedLabel,
  Locale locale,
  bool missingSpecies,
  bool missingStage,
  String petId,
  String serverSpecies,
  int stage,
});

typedef _CompanionPortraitLocaleSample = ({
  String? expectedAsset,
  String expectedLabel,
  String expectedName,
  String expectedSpecies,
  Locale locale,
  String petId,
  String serverName,
  String serverSpecies,
  int stage,
});

typedef _PilotLocaleSample = ({
  String expectedLabel,
  bool legacyId,
  Locale locale,
  String? pilotId,
  String serverName,
});

typedef _PilotPortraitLocaleSample = ({
  String expectedLabel,
  String expectedName,
  Locale locale,
});

typedef _RouteTrailLocaleSample = ({
  String countLabel,
  Locale locale,
  String routeSemantics,
  List<String> nodeNames,
});

typedef _NodeLandmarkLocaleSample = ({
  String landmarkSemantics,
  Locale locale,
  String nodeName,
  String positionLabel,
});

typedef _PilotProgressLocaleSample = ({
  String? expectedLabel,
  bool legacyProgression,
  Locale locale,
});

void main() {
  test('discovered route node count covers Russian and English', () {
    final AppLocalizationsEn english = AppLocalizationsEn();
    final AppLocalizationsRu russian = AppLocalizationsRu();

    expect(english.homeDiscoveredRouteNodes(2), 'Discovered nodes: 2');
    expect(russian.homeDiscoveredRouteNodes(21), 'Открыто узлов: 21');
  });

  test('ready event summary covers Russian and English', () {
    final AppLocalizationsEn english = AppLocalizationsEn();
    final AppLocalizationsRu russian = AppLocalizationsRu();

    expect(
      english.platformJourneyReadyEventSummary('Signal summary'),
      'About event: Signal summary',
    );
    expect(
      russian.platformJourneyReadyEventSummary('Описание сигнала'),
      'О событии: Описание сигнала',
    );
  });

  test('current journey expedition label covers Russian and English', () {
    final AppLocalizationsEn english = AppLocalizationsEn();
    final AppLocalizationsRu russian = AppLocalizationsRu();

    expect(
      english.platformJourneyExpedition('Signal from the Fog Sector'),
      'Expedition: Signal from the Fog Sector',
    );
    expect(
      russian.platformJourneyExpedition('Сигнал из туманного сектора'),
      'Экспедиция: Сигнал из туманного сектора',
    );
  });

  test('current journey companion label covers Russian and English', () {
    final AppLocalizationsEn english = AppLocalizationsEn();
    final AppLocalizationsRu russian = AppLocalizationsRu();

    expect(
      english.platformJourneyActiveCompanion('Spark'),
      'Active companion: Spark',
    );
    expect(
      russian.platformJourneyActiveCompanion('Искра'),
      'Активный спутник: Искра',
    );
  });

  test('current journey companion progression covers Russian and English', () {
    final AppLocalizationsEn english = AppLocalizationsEn();
    final AppLocalizationsRu russian = AppLocalizationsRu();

    expect(
      english.platformJourneyCompanionProgression(6, 742),
      'Companion progression: level 6 · bond 742',
    );
    expect(
      russian.platformJourneyCompanionProgression(6, 742),
      'Прогресс спутника: уровень 6 · связь 742',
    );
  });

  test('current journey companion form covers Russian and English', () {
    final AppLocalizationsEn english = AppLocalizationsEn();
    final AppLocalizationsRu russian = AppLocalizationsRu();

    expect(
      english.platformJourneyCompanionForm('lumin', 'Adult · form 3'),
      'Companion form: lumin · Adult · form 3',
    );
    expect(
      russian.platformJourneyCompanionForm('люмин', 'Взрослый · форма 3'),
      'Форма спутника: люмин · Взрослый · форма 3',
    );
  });

  test('current journey pilot label covers Russian and English', () {
    final AppLocalizationsEn english = AppLocalizationsEn();
    final AppLocalizationsRu russian = AppLocalizationsRu();

    expect(english.platformJourneyPilot('Navigator'), 'Pilot: Navigator');
    expect(russian.platformJourneyPilot('Навигатор'), 'Пилот: Навигатор');
  });

  test('current journey pilot progression covers Russian and English', () {
    final AppLocalizationsEn english = AppLocalizationsEn();
    final AppLocalizationsRu russian = AppLocalizationsRu();

    expect(
      english.platformJourneyPilotProgression(7, 888, 1400, 512),
      'Pilot progression: level 7 · XP 888 / 1400 · 512 XP to next level',
    );
    expect(
      russian.platformJourneyPilotProgression(7, 888, 1400, 512),
      'Прогресс пилота: уровень 7 · XP 888 / 1400 · '
      'до следующего уровня 512 XP',
    );
  });

  test('ready choice label covers Russian and English', () {
    final AppLocalizationsEn english = AppLocalizationsEn();
    final AppLocalizationsRu russian = AppLocalizationsRu();

    expect(
      english.platformJourneyReadyChoice('Follow the echo'),
      'Available choice: Follow the echo',
    );
    expect(
      russian.platformJourneyReadyChoice('Последовать за эхом'),
      'Доступный вариант: Последовать за эхом',
    );
  });

  test('ready choice description label covers Russian and English', () {
    final AppLocalizationsEn english = AppLocalizationsEn();
    final AppLocalizationsRu russian = AppLocalizationsRu();

    expect(
      english.platformJourneyReadyChoiceDescription('Follow the signal.'),
      'About choice: Follow the signal.',
    );
    expect(
      russian.platformJourneyReadyChoiceDescription('Следовать за сигналом.'),
      'О варианте: Следовать за сигналом.',
    );
  });

  test('ready choice reward label covers Russian and English', () {
    final AppLocalizationsEn english = AppLocalizationsEn();
    final AppLocalizationsRu russian = AppLocalizationsRu();

    expect(
      english.platformJourneyReadyChoiceRewards('+31 XP · +6 bond'),
      'Choice rewards: +31 XP · +6 bond',
    );
    expect(
      russian.platformJourneyReadyChoiceRewards('+31 XP · +6 связь'),
      'Награды за вариант: +31 XP · +6 связь',
    );
  });

  test('ready choice requirement label covers Russian and English', () {
    final AppLocalizationsEn english = AppLocalizationsEn();
    final AppLocalizationsRu russian = AppLocalizationsRu();

    expect(
      english.platformJourneyReadyChoiceRequirement('Unlock Steady Step.'),
      'Requirement: Unlock Steady Step.',
    );
    expect(
      russian.platformJourneyReadyChoiceRequirement('Откройте Ровный шаг.'),
      'Условие: Откройте Ровный шаг.',
    );
  });

  test('equipped slot progress covers Russian and English plurals', () {
    final AppLocalizationsEn english = AppLocalizationsEn();
    final AppLocalizationsRu russian = AppLocalizationsRu();

    expect(english.homeEquipmentSlotsEquipped(1, 2), '1 of 2 slots equipped');
    expect(
      russian.homeEquipmentSlotsEquipped(13, 21),
      'Экипировано: 13 из 21 слота',
    );
  });

  test('available event choice count covers Russian and English plurals', () {
    final AppLocalizationsEn english = AppLocalizationsEn();
    final AppLocalizationsRu russian = AppLocalizationsRu();

    expect(english.homeEventChoicesAvailable(2), '2 choices available');
    expect(russian.homeEventChoicesAvailable(21), 'Доступен 21 вариант');
  });

  test('craftable recipe count covers Russian and English plurals', () {
    final AppLocalizationsEn english = AppLocalizationsEn();
    final AppLocalizationsRu russian = AppLocalizationsRu();

    expect(english.homeCraftingRecipesReady(2), '2 recipes ready to craft');
    expect(russian.homeCraftingRecipesReady(21), '21 рецепт готов к созданию');
  });

  test('ready item upgrade count covers Russian and English plurals', () {
    final AppLocalizationsEn english = AppLocalizationsEn();
    final AppLocalizationsRu russian = AppLocalizationsRu();

    expect(english.homeItemUpgradesReady(2), '2 upgrades ready to apply');
    expect(russian.homeItemUpgradesReady(21), 'Можно применить 21 улучшение');
  });

  test('equippable inventory count covers Russian and English plurals', () {
    final AppLocalizationsEn english = AppLocalizationsEn();
    final AppLocalizationsRu russian = AppLocalizationsRu();

    expect(english.homeInventoryItemsReadyToEquip(2), '2 items ready to equip');
    expect(
      russian.homeInventoryItemsReadyToEquip(21),
      'Можно экипировать 21 предмет',
    );
  });

  test('Russian quest remaining guidance covers the one plural category', () {
    final AppLocalizationsRu russian = AppLocalizationsRu();

    expect(
      russian.platformQuestStepsRemaining(21),
      'До выполнения: ещё 21 шаг',
    );
    expect(
      russian.platformQuestEventsRemaining(101),
      'До выполнения: ещё 101 событие',
    );
  });

  test('Russian skill collection covers the one plural category', () {
    final AppLocalizationsRu russian = AppLocalizationsRu();

    expect(
      russian.platformSkillsCollectionRemaining(21),
      'До полной коллекции: 21 навык',
    );
  });

  test('Russian quest reward count covers the one plural category', () {
    final AppLocalizationsRu russian = AppLocalizationsRu();

    expect(
      russian.platformQuestRewardsAvailable(21),
      'Доступна 21 награда за задание',
    );
  });

  test('Russian unlockable skill count covers the one plural category', () {
    final AppLocalizationsRu russian = AppLocalizationsRu();

    expect(
      russian.platformSkillsAvailableToUnlock(21),
      'Можно открыть 21 навык',
    );
  });

  test('Russian evolvable companion count covers the one plural category', () {
    final AppLocalizationsRu russian = AppLocalizationsRu();

    expect(
      russian.platformCompanionsReadyToEvolve(21),
      'К эволюции готов 21 питомец',
    );
  });

  test('Russian equippable cosmetic count covers the one plural category', () {
    final AppLocalizationsRu russian = AppLocalizationsRu();

    expect(
      russian.platformCosmeticsAvailableToEquip(21),
      'Можно надеть 21 образ',
    );
  });

  testWidgets(
    'multiple equippable cosmetics use accessible compact English guidance',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final SemanticsHandle semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        _LocalizedPlatformApp(
          locale: const Locale('en'),
          textScale: 1.6,
          child: PlatformScreen(
            loader: () async => platformSnapshot(
              ownedCosmetics: const <String>[
                'pilot-scarf',
                'trail-banner',
                'dawn-frame',
              ],
              includeProfileCosmetics: true,
            ),
            homeLoader: () async => HomeSnapshot.demo,
            recordExperimentExposures: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Finder guidance = find.byKey(
        const Key('platform-equippable-cosmetics'),
      );
      await _bringIntoView(tester, guidance);
      expect(find.text('2 cosmetics ready to equip'), findsOneWidget);
      expect(
        find.bySemanticsLabel('2 cosmetics ready to equip'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets('zero equippable cosmetics omit aggregate guidance', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _LocalizedPlatformApp(
        locale: const Locale('en'),
        child: PlatformScreen(
          loader: () async => platformSnapshot(),
          homeLoader: () async => HomeSnapshot.demo,
          recordExperimentExposures: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _bringIntoView(
      tester,
      find.byKey(const Key('platform-cosmetics-collection-summary')),
    );
    expect(
      find.byKey(const Key('platform-equippable-cosmetics')),
      findsNothing,
    );
  });

  testWidgets('multiple evolvable companions use English plural guidance', (
    WidgetTester tester,
  ) async {
    final Map<String, dynamic> json = platformSnapshotJson();
    final Map<String, dynamic> userState =
        json['userState']! as Map<String, dynamic>;
    final List<dynamic> pets = userState['pets']! as List<dynamic>;
    (pets[1] as Map<String, dynamic>)['bond'] = 45;
    final SemanticsHandle semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _LocalizedPlatformApp(
        locale: const Locale('en'),
        child: PlatformScreen(
          loader: () async => PlatformSnapshot.fromJson(json),
          homeLoader: () async => HomeSnapshot.demo,
          recordExperimentExposures: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder guidance = find.byKey(
      const Key('platform-evolvable-companions'),
    );
    await _bringIntoView(tester, guidance);
    expect(find.text('2 companions ready to evolve'), findsOneWidget);
    expect(
      find.bySemanticsLabel('2 companions ready to evolve'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('zero evolvable companions omit aggregate guidance', (
    WidgetTester tester,
  ) async {
    final Map<String, dynamic> json = platformSnapshotJson();
    final Map<String, dynamic> userState =
        json['userState']! as Map<String, dynamic>;
    final List<dynamic> pets = userState['pets']! as List<dynamic>;
    (pets[0] as Map<String, dynamic>)['evolutionStage'] = 1;

    await tester.pumpWidget(
      _LocalizedPlatformApp(
        locale: const Locale('en'),
        child: PlatformScreen(
          loader: () async => PlatformSnapshot.fromJson(json),
          homeLoader: () async => HomeSnapshot.demo,
          recordExperimentExposures: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _bringIntoView(
      tester,
      find.byKey(const Key('platform-pet-growth-spark-v1')),
    );
    expect(
      find.byKey(const Key('platform-evolvable-companions')),
      findsNothing,
    );
  });

  testWidgets('multiple unlockable skills use English plural guidance', (
    WidgetTester tester,
  ) async {
    final Map<String, dynamic> json = platformSnapshotJson();
    final Map<String, dynamic> content =
        json['content']! as Map<String, dynamic>;
    final List<dynamic> skills = content['skills']! as List<dynamic>;
    skills.add(<String, dynamic>{
      'skillId': 'echo-navigation',
      'name': 'Echo Navigation',
      'description': 'Strengthens route reading.',
      'requiredSeasonXp': 200,
    });
    final SemanticsHandle semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _LocalizedPlatformApp(
        locale: const Locale('en'),
        child: PlatformScreen(
          loader: () async => PlatformSnapshot.fromJson(json),
          homeLoader: () async => HomeSnapshot.demo,
          recordExperimentExposures: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder guidance = find.byKey(const Key('platform-unlockable-skills'));
    await _bringIntoView(tester, guidance);
    expect(find.text('2 skills ready to unlock'), findsOneWidget);
    expect(find.bySemanticsLabel('2 skills ready to unlock'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('zero unlockable skills omit aggregate guidance', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _LocalizedPlatformApp(
        locale: const Locale('en'),
        child: PlatformScreen(
          loader: () async => platformSnapshot(seasonXp: 40),
          homeLoader: () async => HomeSnapshot.demo,
          recordExperimentExposures: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _bringIntoView(
      tester,
      find.byKey(const Key('platform-skills-collection-summary')),
    );
    expect(find.byKey(const Key('platform-unlockable-skills')), findsNothing);
  });

  testWidgets('multiple claimable quests use English plural guidance', (
    WidgetTester tester,
  ) async {
    final Map<String, dynamic> json = platformSnapshotJson();
    final Map<String, dynamic> userState =
        json['userState']! as Map<String, dynamic>;
    final List<dynamic> quests = userState['quests']! as List<dynamic>;
    (quests[1] as Map<String, dynamic>)['ready'] = true;
    final SemanticsHandle semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _LocalizedPlatformApp(
        locale: const Locale('en'),
        child: PlatformScreen(
          loader: () async => PlatformSnapshot.fromJson(json),
          homeLoader: () async => HomeSnapshot.demo,
          recordExperimentExposures: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder guidance = find.byKey(
      const Key('platform-claimable-quest-rewards'),
    );
    await _bringIntoView(tester, guidance);
    expect(find.text('2 quest rewards available'), findsOneWidget);
    expect(find.bySemanticsLabel('2 quest rewards available'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('zero claimable quests omit aggregate guidance', (
    WidgetTester tester,
  ) async {
    final Map<String, dynamic> json = platformSnapshotJson();
    final Map<String, dynamic> userState =
        json['userState']! as Map<String, dynamic>;
    final List<dynamic> quests = userState['quests']! as List<dynamic>;
    (quests[0] as Map<String, dynamic>)['claimed'] = true;

    await tester.pumpWidget(
      _LocalizedPlatformApp(
        locale: const Locale('en'),
        child: PlatformScreen(
          loader: () async => PlatformSnapshot.fromJson(json),
          homeLoader: () async => HomeSnapshot.demo,
          recordExperimentExposures: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _bringIntoView(
      tester,
      find.byKey(const Key('platform-claim-quest-walk-3000')),
    );
    expect(
      find.byKey(const Key('platform-claimable-quest-rewards')),
      findsNothing,
    );
  });

  testWidgets('complete skill collection uses calm English guidance', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _LocalizedPlatformApp(
        locale: const Locale('en'),
        child: PlatformScreen(
          loader: () async => platformSnapshot(
            unlockedSkills: const <String>[
              'steady-step',
              'trail-memory',
              'retired-skill',
            ],
          ),
          homeLoader: () async => HomeSnapshot.demo,
          recordExperimentExposures: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder summary = find.byKey(
      const Key('platform-skills-collection-summary'),
    );
    await _bringIntoView(tester, summary);
    expect(
      find.text('Skills unlocked: 2 of 2 · All pilot skills unlocked'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Skills unlocked: 2 of 2. All pilot skills unlocked',
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('claimable season rewards use English plural guidance', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _LocalizedPlatformApp(
        locale: const Locale('en'),
        child: PlatformScreen(
          loader: () async => platformSnapshot(
            seasonXp: 320,
            achievements: const <String>['season-reward-1'],
          ),
          homeLoader: () async => HomeSnapshot.demo,
          recordExperimentExposures: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder guidance = find.text('2 season rewards available');
    await _bringIntoView(tester, guidance);
    expect(guidance, findsOneWidget);
    expect(find.bySemanticsLabel('2 season rewards available'), findsOneWidget);
    semantics.dispose();
  });

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

  testWidgets('journey time and duration follow the RU and EN locale', (
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
                durationSeconds: 3900,
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
                  durationSeconds: 2520,
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
      final String currentDuration = locale.languageCode == 'ru'
          ? 'Длительность: 1 ч 5 мин'
          : 'Duration: 1 h 5 min';
      expect(find.text(currentDuration), findsOneWidget);
      expect(
        find.byKey(const Key('platform-journey-completion-duration')),
        findsOneWidget,
      );
      final String currentSemanticPrefix = locale.languageCode == 'ru'
          ? 'Поход 7 завершён. Принято решений: 1'
          : 'Journey 7 completed. Decisions made: 1';
      expect(
        find.bySemanticsLabel(
          RegExp(
            '^${RegExp.escape(currentSemanticPrefix)}\\. '
            '${RegExp.escape(currentLabel)}\\. '
            '${RegExp.escape(currentDuration)}\\.',
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
      expect(
        find.descendant(
          of: currentDecision,
          matching: find.text(currentDecisionLabel),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('platform-journey-decision-legacy-event-v1-time')),
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
      final String archivedDuration = locale.languageCode == 'ru'
          ? 'Длительность: 42 мин'
          : 'Duration: 42 min';
      expect(find.text(archivedDuration), findsOneWidget);
      expect(
        find.byKey(const Key('platform-journey-archive-6-time')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('platform-journey-archive-6-duration')),
        findsOneWidget,
      );
      final String archivedSemanticPrefix = locale.languageCode == 'ru'
          ? 'Поход 6. Принято решений: 1'
          : 'Journey 6. Decisions made: 1';
      expect(
        find.bySemanticsLabel(
          RegExp(
            '^${RegExp.escape(archivedSemanticPrefix)}\\. '
            '${RegExp.escape(archivedLabel)}\\. '
            '${RegExp.escape(archivedDuration)}\\.',
          ),
        ),
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
        find.byKey(const Key('platform-journey-decision-mirror-delta-v1-time')),
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
          loader: () async =>
              platformSnapshot(seasonXp: 40, includeProfileCosmetics: true),
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
              totalDurationSeconds: 65700,
              shortestDurationSeconds: 1800,
              shortestJourneyNumber: 4,
              shortestJourneyCompletedAt: '2026-07-24T11:00:00Z',
              longestDurationSeconds: 12600,
              longestJourneyNumber: 3,
              longestJourneyCompletedAt: '2026-07-25T12:00:00Z',
              averageDurationSeconds: 7300,
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
    final String recordCompletedAt = _formattedChronicleRecordTime(
      tester,
      find.byKey(const Key('platform-journey-chronicle')),
      '2026-07-25T12:00:00Z',
      russian: false,
    );
    final String shortestCompletedAt = _formattedChronicleShortestTime(
      tester,
      find.byKey(const Key('platform-journey-chronicle')),
      '2026-07-24T11:00:00Z',
      russian: false,
    );
    expect(find.text('Journey chronicle'), findsOneWidget);
    expect(find.text('Time in journeys: 18 h 15 min'), findsOneWidget);
    expect(
      find.byKey(const Key('platform-journey-chronicle-duration')),
      findsOneWidget,
    );
    expect(find.text('Shortest journey #4: 30 min'), findsOneWidget);
    expect(
      find.byKey(const Key('platform-journey-chronicle-shortest-duration')),
      findsOneWidget,
    );
    expect(find.text(shortestCompletedAt), findsOneWidget);
    expect(
      find.byKey(const Key('platform-journey-chronicle-shortest-completed-at')),
      findsOneWidget,
    );
    expect(find.text('Longest journey #3: 3 h 30 min'), findsOneWidget);
    expect(
      find.byKey(const Key('platform-journey-chronicle-longest-duration')),
      findsOneWidget,
    );
    expect(find.text(recordCompletedAt), findsOneWidget);
    expect(
      find.byKey(const Key('platform-journey-chronicle-record-completed-at')),
      findsOneWidget,
    );
    expect(find.text('Average journey: 2 h 1 min'), findsOneWidget);
    expect(
      find.byKey(const Key('platform-journey-chronicle-average-duration')),
      findsOneWidget,
    );
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
        'Time in journeys: 18 h 15 min. '
        'Shortest journey #4: 30 min. '
        '$shortestCompletedAt. '
        'Longest journey #3: 3 h 30 min. '
        '$recordCompletedAt. '
        'Average journey: 2 h 1 min. '
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
    expect(find.text('5 stages left to complete'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'First journey: 1 of 6 stages completed. 5 stages left to complete',
      ),
      findsOneWidget,
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
    expect(find.text('60 more season XP until level 1 reward'), findsOneWidget);
    expect(
      find.bySemanticsLabel('60 more season XP until level 1 reward'),
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
      find.byKey(const Key('platform-pet-compact-moss-v1')),
    );
    expect(find.text('Next evolution: 33 more bond'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Companion “Moss” bond: 12 of 45. '
        '33 more bond to next evolution',
      ),
      findsOneWidget,
    );

    await _bringIntoView(
      tester,
      find.byKey(const Key('platform-skills-collection-summary')),
    );
    final Semantics skillCollectionSummary = tester.widget<Semantics>(
      find.byKey(const Key('platform-skills-collection-summary')),
    );
    expect(
      skillCollectionSummary.properties.label,
      'Skills unlocked: 1 of 2. 1 skill left to unlock',
    );
    expect(
      find.text('Skills unlocked: 1 of 2 · 1 skill left to unlock'),
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
      find.byKey(const Key('platform-skill-compact-trail-memory')),
    );
    expect(find.text('60 more season XP to unlock'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('60 more season XP to unlock')),
      findsOneWidget,
    );
    final OutlinedButton unavailableSkillButton = tester.widget<OutlinedButton>(
      find.byKey(const Key('platform-unlock-skill-trail-memory')),
    );
    expect(unavailableSkillButton.onPressed, isNull);

    await _bringIntoView(
      tester,
      find.byKey(const Key('platform-claimable-quest-rewards')),
    );
    expect(find.text('1 quest reward available'), findsOneWidget);
    expect(find.bySemanticsLabel('1 quest reward available'), findsOneWidget);

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
      find.byKey(const Key('platform-quest-compact-resolve-3')),
    );
    expect(find.text('1 more event to complete'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Quest “Explorer” progress: 2 of 3. 1 more event to complete',
      ),
      findsOneWidget,
    );

    await _bringIntoView(
      tester,
      find.byKey(const Key('platform-cosmetics-collection-summary')),
    );
    final Semantics collectionSummary = tester.widget<Semantics>(
      find.byKey(const Key('platform-cosmetics-collection-summary')),
    );
    expect(
      collectionSummary.properties.label,
      '1 of 4 collected. 3 cosmetics left to collect',
    );
    expect(
      find.text('1 of 4 collected · 3 cosmetics left to collect'),
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
    expect(
      find.bySemanticsLabel('0 of 2 unlocked. 2 achievements left to unlock'),
      findsOneWidget,
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

  testWidgets('legacy duration records keep generic English labels', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _LocalizedPlatformApp(
        locale: const Locale('en'),
        child: PlatformScreen(
          loader: () async => platformSnapshot(),
          homeLoader: () async => _homeWithPersistedDecision(
            journeyChronicle: const HomeJourneyChronicle(
              completedJourneyCount: 2,
              decisionCount: 0,
              totalDurationSeconds: 7200,
              shortestDurationSeconds: 1800,
              longestDurationSeconds: 3600,
              averageDurationSeconds: 3600,
              pilotExperienceGained: 0,
              petBondGained: 0,
            ),
          ),
          recordExperimentExposures: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _bringIntoView(
      tester,
      find.byKey(const Key('platform-journey-chronicle')),
    );
    expect(find.text('Shortest journey: 30 min'), findsOneWidget);
    expect(find.textContaining('Shortest journey #'), findsNothing);
    expect(find.text('Longest journey: 1 h 0 min'), findsOneWidget);
    expect(find.textContaining('Longest journey #'), findsNothing);
    expect(
      find.byKey(const Key('platform-journey-chronicle-shortest-completed-at')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('platform-journey-chronicle-record-completed-at')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('platform-journey-chronicle-shortest-duration')),
      findsOneWidget,
    );
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

  testWidgets(
    'current journey expedition follows stable identity at compact large text',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final _JourneyLocaleSample sample in <_JourneyLocaleSample>[
        (
          locale: const Locale('en'),
          expeditionId: 'starter-expedition-v1',
          serverName: 'Literal server expedition',
          expectedLabel: 'Expedition: Signal from the Fog Sector',
          energyLabel: 'ENERGY progress: 12 of 30',
        ),
        (
          locale: const Locale('ru'),
          expeditionId: 'starter-expedition-v1',
          serverName: 'Literal server expedition',
          expectedLabel: 'Экспедиция: Сигнал из туманного сектора',
          energyLabel: 'Прогресс ENERGY: 12 из 30',
        ),
        (
          locale: const Locale('en'),
          expeditionId: 'future-expedition-v2',
          serverName: 'Literal future expedition',
          expectedLabel: 'Expedition: Literal future expedition',
          energyLabel: 'ENERGY progress: 12 of 30',
        ),
      ]) {
        await tester.pumpWidget(
          _LocalizedPlatformApp(
            locale: sample.locale,
            textScale: 1.6,
            child: PlatformScreen(
              loader: () async => platformSnapshot(weeklyRouteProgress: 100),
              homeLoader: () async => _homeWithPersistedDecision(
                expeditionId: sample.expeditionId,
                expeditionName: sample.serverName,
                expeditionProgress: 12,
                requiredEnergy: 30,
                currentNodeId: 'future-decoy-node-v1',
                currentNodeName: 'Literal decoy node',
                unlockedEvent: _readyEvent(
                  eventId: 'future-decoy-event-v1',
                  title: 'Literal decoy event',
                  summary: 'Literal decoy event summary',
                ),
              ),
              recordExperimentExposures: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final Finder log = find.byKey(
          const Key('platform-journey-decision-log'),
        );
        await _bringIntoView(tester, log);
        expect(
          find.byKey(const Key('platform-current-journey-expedition')),
          findsOneWidget,
        );
        expect(find.text(sample.expectedLabel), findsOneWidget);
        expect(find.bySemanticsLabel(sample.expectedLabel), findsOneWidget);
        expect(find.textContaining('Expedition: Literal decoy'), findsNothing);
        expect(find.textContaining('Экспедиция: Literal decoy'), findsNothing);
        final Finder signalFinder = find.byKey(
          const Key('platform-current-journey-expedition-progress-signal'),
        );
        await _bringIntoView(tester, signalFinder);
        final ExpeditionProgressSignal signal = tester
            .widget<ExpeditionProgressSignal>(signalFinder);
        expect(signal.expeditionId, sample.expeditionId);
        expect(signal.progress, 12);
        expect(signal.target, 30);
        expect(signal.height, 72);
        final String kind = sample.expeditionId == 'starter-expedition-v1'
            ? 'outerBeacon'
            : 'unknown';
        expect(
          find.byKey(
            Key('expedition-progress-signal-${sample.expeditionId}-$kind'),
          ),
          findsOneWidget,
        );
        expect(find.text(sample.energyLabel), findsOneWidget);
        expect(find.bySemanticsLabel(sample.energyLabel), findsOneWidget);
        expect(
          find.descendant(
            of: signalFinder,
            matching: find.byType(LinearProgressIndicator),
          ),
          findsNothing,
        );
        if (sample.expeditionId == 'starter-expedition-v1') {
          expect(find.textContaining(sample.serverName), findsNothing);
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'current journey pilot follows Home identity at compact large text',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final _PilotLocaleSample sample in <_PilotLocaleSample>[
        (
          locale: const Locale('en'),
          pilotId: 'navigator-v1',
          serverName: 'Literal server pilot',
          expectedLabel: 'Pilot: Navigator',
          legacyId: false,
        ),
        (
          locale: const Locale('ru'),
          pilotId: 'navigator-v1',
          serverName: 'Literal server pilot',
          expectedLabel: 'Пилот: Навигатор',
          legacyId: false,
        ),
        (
          locale: const Locale('en'),
          pilotId: 'future-pilot-v2',
          serverName: 'Literal future pilot',
          expectedLabel: 'Pilot: Literal future pilot',
          legacyId: false,
        ),
        (
          locale: const Locale('en'),
          pilotId: null,
          serverName: 'Literal legacy pilot',
          expectedLabel: 'Pilot: Literal legacy pilot',
          legacyId: true,
        ),
      ]) {
        await tester.pumpWidget(
          _LocalizedPlatformApp(
            locale: sample.locale,
            textScale: 1.6,
            child: PlatformScreen(
              loader: () async => platformSnapshot(),
              homeLoader: () async => _homeWithPersistedDecision(
                pilotId: sample.pilotId,
                pilotName: sample.serverName,
                legacyPilotId: sample.legacyId,
                withDecisionRewards: true,
                currentNodeId: 'future-decoy-node-v1',
                currentNodeName: 'Literal decoy pilot',
                unlockedEvent: _readyEvent(
                  eventId: 'future-decoy-event-v1',
                  title: 'Literal decoy pilot',
                  summary: 'Literal decoy pilot summary',
                ),
              ),
              recordExperimentExposures: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final Finder log = find.byKey(
          const Key('platform-journey-decision-log'),
        );
        await _bringIntoView(tester, log);
        expect(
          find.byKey(const Key('platform-current-journey-pilot')),
          findsOneWidget,
        );
        expect(find.text(sample.expectedLabel), findsOneWidget);
        expect(find.bySemanticsLabel(sample.expectedLabel), findsOneWidget);
        if (sample.pilotId != 'navigator-v1') {
          expect(find.text('Pilot: Navigator'), findsNothing);
          expect(find.text('Пилот: Навигатор'), findsNothing);
        }
        if (sample.pilotId == 'navigator-v1') {
          expect(find.textContaining(sample.serverName), findsNothing);
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('current journey pilot portrait follows known Home identity', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final _PilotPortraitLocaleSample sample
        in <_PilotPortraitLocaleSample>[
          (
            expectedLabel: 'Pilot Navigator',
            expectedName: 'Navigator',
            locale: const Locale('en'),
          ),
          (
            expectedLabel: 'Пилот Навигатор',
            expectedName: 'Навигатор',
            locale: const Locale('ru'),
          ),
        ]) {
      await tester.pumpWidget(
        _LocalizedPlatformApp(
          locale: sample.locale,
          textScale: 1.6,
          child: PlatformScreen(
            loader: () async => platformSnapshot(),
            homeLoader: () async => _homeWithPersistedDecision(
              pilotId: 'navigator-v1',
              pilotName: 'Literal server pilot',
            ),
            recordExperimentExposures: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Finder log = find.byKey(const Key('platform-journey-decision-log'));
      await _bringIntoView(tester, log);
      final Finder portraitSemantics = find.byKey(
        const Key('platform-current-journey-pilot-portrait'),
      );
      final Finder portraitFinder = find.descendant(
        of: portraitSemantics,
        matching: find.byType(PilotPortrait),
      );
      expect(portraitSemantics, findsOneWidget);
      expect(find.bySemanticsLabel(sample.expectedLabel), findsOneWidget);
      expect(portraitFinder, findsOneWidget);
      final PilotPortrait portrait = tester.widget<PilotPortrait>(
        portraitFinder,
      );
      expect(portrait.name, sample.expectedName);
      expect(portrait.highlighted, isTrue);
      expect(portrait.equippedCosmeticIds, isEmpty);
      expect(portrait.illustrationAsset, PilotPortrait.assetPath);
      expect(
        find.byKey(const Key('platform-current-journey-companion-portrait')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }

    semantics.dispose();
  });

  testWidgets(
    'current journey pilot portrait fails closed for unknown Home identity',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final List<HomeSnapshot> unsupportedHomes = <HomeSnapshot>[
        _homeWithPersistedDecision(
          pilotId: 'future-pilot-v2',
          pilotName: 'Literal future pilot',
        ),
        _homeWithPersistedDecision(
          legacyPilotId: true,
          pilotName: 'Literal legacy pilot',
        ),
      ];
      final List<String> expectedLabels = <String>[
        'Pilot: Literal future pilot',
        'Pilot: Literal legacy pilot',
      ];

      for (int index = 0; index < unsupportedHomes.length; index += 1) {
        await tester.pumpWidget(
          _LocalizedPlatformApp(
            locale: const Locale('en'),
            textScale: 1.6,
            child: PlatformScreen(
              loader: () async => platformSnapshot(),
              homeLoader: () async => unsupportedHomes[index],
              recordExperimentExposures: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final Finder log = find.byKey(
          const Key('platform-journey-decision-log'),
        );
        await _bringIntoView(tester, log);
        expect(
          find.byKey(const Key('platform-current-journey-pilot-portrait')),
          findsNothing,
        );
        expect(
          find.descendant(of: log, matching: find.byType(PilotPortrait)),
          findsNothing,
        );
        expect(find.text(expectedLabels[index]), findsOneWidget);
        expect(find.bySemanticsLabel(expectedLabels[index]), findsOneWidget);
        expect(
          find.byKey(const Key('platform-current-journey-companion-portrait')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'current journey pilot progression follows Home at compact large text',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final _PilotProgressLocaleSample sample
          in <_PilotProgressLocaleSample>[
            (
              locale: const Locale('en'),
              expectedLabel:
                  'Pilot progression: level 7 · XP 888 / 1400 · '
                  '512 XP to next level',
              legacyProgression: false,
            ),
            (
              locale: const Locale('ru'),
              expectedLabel:
                  'Прогресс пилота: уровень 7 · XP 888 / 1400 · '
                  'до следующего уровня 512 XP',
              legacyProgression: false,
            ),
            (
              locale: const Locale('en'),
              expectedLabel: null,
              legacyProgression: true,
            ),
          ]) {
        await tester.pumpWidget(
          _LocalizedPlatformApp(
            locale: sample.locale,
            textScale: 1.6,
            child: PlatformScreen(
              loader: () async => platformSnapshot(seasonXp: 220),
              homeLoader: () async => _homeWithPersistedDecision(
                pilotLevel: 7,
                pilotCurrentExperience: 888,
                pilotNextLevelExperience: 1400,
                legacyPilotProgression: sample.legacyProgression,
                withDecisionRewards: true,
              ),
              recordExperimentExposures: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final Finder log = find.byKey(
          const Key('platform-journey-decision-log'),
        );
        await _bringIntoView(tester, log);
        final Finder progression = find.byKey(
          const Key('platform-current-journey-pilot-progression'),
        );
        if (sample.expectedLabel case final String expectedLabel) {
          expect(progression, findsOneWidget);
          expect(find.text(expectedLabel), findsOneWidget);
          expect(find.bySemanticsLabel(expectedLabel), findsOneWidget);
        } else {
          expect(progression, findsNothing);
          expect(
            find.descendant(
              of: log,
              matching: find.textContaining('Pilot progression:'),
            ),
            findsNothing,
          );
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'current journey companion progression follows Home at compact large text',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final _CompanionProgressLocaleSample sample
          in <_CompanionProgressLocaleSample>[
            (
              locale: const Locale('en'),
              expectedLabel: 'Companion progression: level 6 · bond 742',
            ),
            (
              locale: const Locale('ru'),
              expectedLabel: 'Прогресс спутника: уровень 6 · связь 742',
            ),
          ]) {
        await tester.pumpWidget(
          _LocalizedPlatformApp(
            locale: sample.locale,
            textScale: 1.6,
            child: PlatformScreen(
              loader: () async =>
                  platformSnapshot(sparkLevel: 12, sparkBond: 999),
              homeLoader: () async => _homeWithPersistedDecision(
                petLevel: 6,
                petBond: 742,
                withDecisionRewards: true,
              ),
              recordExperimentExposures: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final Finder log = find.byKey(
          const Key('platform-journey-decision-log'),
        );
        await _bringIntoView(tester, log);
        expect(
          find.byKey(
            const Key('platform-current-journey-companion-progression'),
          ),
          findsOneWidget,
        );
        expect(find.text(sample.expectedLabel), findsOneWidget);
        expect(find.bySemanticsLabel(sample.expectedLabel), findsOneWidget);
        expect(
          find.descendant(
            of: log,
            matching: find.textContaining('level 12 · bond 999'),
          ),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'current journey companion form follows Home at compact large text',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final _CompanionFormLocaleSample sample
          in <_CompanionFormLocaleSample>[
            (
              locale: const Locale('en'),
              petId: 'spark-v1',
              serverSpecies: 'Literal server species',
              stage: 2,
              expectedLabel: 'Companion form: lumin · Adult · form 3',
              missingSpecies: false,
              missingStage: false,
            ),
            (
              locale: const Locale('ru'),
              petId: 'spark-v1',
              serverSpecies: 'Literal server species',
              stage: 2,
              expectedLabel: 'Форма спутника: люмин · Взрослый · форма 3',
              missingSpecies: false,
              missingStage: false,
            ),
            (
              locale: const Locale('en'),
              petId: 'future-companion-v2',
              serverSpecies: 'Literal future species',
              stage: 5,
              expectedLabel: 'Companion form: Literal future species · Form 6',
              missingSpecies: false,
              missingStage: false,
            ),
            (
              locale: const Locale('en'),
              petId: 'spark-v1',
              serverSpecies: 'Missing species',
              stage: 2,
              expectedLabel: null,
              missingSpecies: true,
              missingStage: false,
            ),
            (
              locale: const Locale('en'),
              petId: 'spark-v1',
              serverSpecies: 'Missing stage species',
              stage: 2,
              expectedLabel: null,
              missingSpecies: false,
              missingStage: true,
            ),
          ]) {
        await tester.pumpWidget(
          _LocalizedPlatformApp(
            locale: sample.locale,
            textScale: 1.6,
            child: PlatformScreen(
              loader: () async => platformSnapshot(
                activePetId: 'moss-v1',
                sparkEvolutionStage: 1,
              ),
              homeLoader: () async => _homeWithPersistedDecision(
                missingPetEvolutionStage: sample.missingStage,
                missingPetSpecies: sample.missingSpecies,
                petEvolutionStage: sample.stage,
                petId: sample.petId,
                petSpecies: sample.serverSpecies,
                withDecisionRewards: true,
              ),
              recordExperimentExposures: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final Finder log = find.byKey(
          const Key('platform-journey-decision-log'),
        );
        await _bringIntoView(tester, log);
        final Finder form = find.byKey(
          const Key('platform-current-journey-companion-form'),
        );
        if (sample.expectedLabel case final String expectedLabel) {
          expect(form, findsOneWidget);
          expect(find.text(expectedLabel), findsOneWidget);
          expect(find.bySemanticsLabel(expectedLabel), findsOneWidget);
        } else {
          expect(form, findsNothing);
          expect(
            find.descendant(
              of: log,
              matching: find.textContaining('Companion form:'),
            ),
            findsNothing,
          );
        }
        expect(
          find.descendant(of: log, matching: find.textContaining('terra')),
          findsNothing,
        );
        expect(
          find.descendant(of: log, matching: find.textContaining('терра')),
          findsNothing,
        );
        if (sample.petId == 'spark-v1' &&
            !sample.missingSpecies &&
            !sample.missingStage) {
          expect(find.textContaining(sample.serverSpecies), findsNothing);
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'current journey companion portrait follows Home at compact large text',
    (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final _CompanionPortraitLocaleSample sample
          in <_CompanionPortraitLocaleSample>[
            (
              expectedAsset: 'assets/characters/companion_spark.webp',
              expectedLabel: 'Spark, lumin, Adult · form 3, active companion',
              expectedName: 'Spark',
              expectedSpecies: 'lumin',
              locale: const Locale('en'),
              petId: 'spark-v1',
              serverName: 'Literal server companion',
              serverSpecies: 'Literal server species',
              stage: 2,
            ),
            (
              expectedAsset: 'assets/characters/companion_spark.webp',
              expectedLabel:
                  'Искра, люмин, Взрослый · форма 3, активный спутник',
              expectedName: 'Искра',
              expectedSpecies: 'люмин',
              locale: const Locale('ru'),
              petId: 'spark-v1',
              serverName: 'Literal server companion',
              serverSpecies: 'Literal server species',
              stage: 2,
            ),
            (
              expectedAsset: null,
              expectedLabel:
                  'Literal future companion, Literal future species, '
                  'Form 6, active companion',
              expectedName: 'Literal future companion',
              expectedSpecies: 'Literal future species',
              locale: const Locale('en'),
              petId: 'future-companion-v2',
              serverName: 'Literal future companion',
              serverSpecies: 'Literal future species',
              stage: 5,
            ),
          ]) {
        await tester.pumpWidget(
          _LocalizedPlatformApp(
            locale: sample.locale,
            textScale: 1.6,
            child: PlatformScreen(
              loader: () async => platformSnapshot(
                activePetId: 'moss-v1',
                sparkEvolutionStage: 1,
              ),
              homeLoader: () async => _homeWithPersistedDecision(
                petEvolutionStage: sample.stage,
                petId: sample.petId,
                petName: sample.serverName,
                petSpecies: sample.serverSpecies,
              ),
              recordExperimentExposures: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final Finder log = find.byKey(
          const Key('platform-journey-decision-log'),
        );
        await _bringIntoView(tester, log);
        final Finder portraitSemantics = find.byKey(
          const Key('platform-current-journey-companion-portrait'),
        );
        final Finder portraitFinder = find.descendant(
          of: portraitSemantics,
          matching: find.byType(CompanionPortrait),
        );
        expect(portraitSemantics, findsOneWidget);
        expect(find.bySemanticsLabel(sample.expectedLabel), findsOneWidget);
        expect(portraitFinder, findsOneWidget);
        final CompanionPortrait portrait = tester.widget<CompanionPortrait>(
          portraitFinder,
        );
        expect(portrait.petId, sample.petId);
        expect(portrait.name, sample.expectedName);
        expect(portrait.species, sample.expectedSpecies);
        expect(portrait.evolutionStage, sample.stage);
        expect(portrait.active, isTrue);
        expect(portrait.equippedCosmeticIds, isEmpty);
        expect(portrait.illustrationAsset, sample.expectedAsset);
        expect(portrait.identity == CompanionIdentity.moss, isFalse);
        expect(tester.takeException(), isNull);
      }

      semantics.dispose();
    },
  );

  testWidgets(
    'current journey companion portrait fails closed on partial Home facts',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final List<HomeSnapshot> incompleteHomes = <HomeSnapshot>[
        _homeWithPersistedDecision(legacyPetId: true),
        _homeWithPersistedDecision(missingPetSpecies: true),
        _homeWithPersistedDecision(missingPetEvolutionStage: true),
      ];

      for (final HomeSnapshot home in incompleteHomes) {
        await tester.pumpWidget(
          _LocalizedPlatformApp(
            locale: const Locale('en'),
            textScale: 1.6,
            child: PlatformScreen(
              loader: () async => platformSnapshot(activePetId: 'moss-v1'),
              homeLoader: () async => home,
              recordExperimentExposures: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final Finder log = find.byKey(
          const Key('platform-journey-decision-log'),
        );
        await _bringIntoView(tester, log);
        expect(
          find.byKey(const Key('platform-current-journey-companion-portrait')),
          findsNothing,
        );
        expect(
          find.descendant(of: log, matching: find.byType(CompanionPortrait)),
          findsNothing,
        );
        expect(
          find.byKey(const Key('platform-current-journey-active-companion')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'current journey companion follows Home identity at compact large text',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final _CompanionLocaleSample sample in <_CompanionLocaleSample>[
        (
          locale: const Locale('en'),
          petId: 'spark-v1',
          serverName: 'Literal server companion',
          expectedLabel: 'Active companion: Spark',
          legacyId: false,
        ),
        (
          locale: const Locale('ru'),
          petId: 'spark-v1',
          serverName: 'Literal server companion',
          expectedLabel: 'Активный спутник: Искра',
          legacyId: false,
        ),
        (
          locale: const Locale('en'),
          petId: 'future-companion-v2',
          serverName: 'Literal future companion',
          expectedLabel: 'Active companion: Literal future companion',
          legacyId: false,
        ),
        (
          locale: const Locale('en'),
          petId: null,
          serverName: 'Literal legacy companion',
          expectedLabel: 'Active companion: Literal legacy companion',
          legacyId: true,
        ),
      ]) {
        await tester.pumpWidget(
          _LocalizedPlatformApp(
            locale: sample.locale,
            textScale: 1.6,
            child: PlatformScreen(
              loader: () async => platformSnapshot(),
              homeLoader: () async => _homeWithPersistedDecision(
                petId: sample.petId,
                petName: sample.serverName,
                legacyPetId: sample.legacyId,
                withDecisionRewards: true,
                unlockedEvent: _readyEvent(
                  eventId: 'future-decoy-event-v1',
                  title: 'Literal decoy event',
                  summary: 'Literal decoy event summary',
                  choices: <HomeEventChoice>[
                    _eventChoice(
                      'future-decoy-choice-v1',
                      requirement: const HomeChoiceRequirement(
                        type: 'PET',
                        slotId: 'PET',
                        slotName: 'Literal decoy slot',
                        itemId: 'moss-v1',
                        itemName: 'Literal decoy companion',
                        description: 'Select the decoy companion.',
                      ),
                    ),
                  ],
                ),
              ),
              recordExperimentExposures: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final Finder log = find.byKey(
          const Key('platform-journey-decision-log'),
        );
        await _bringIntoView(tester, log);
        expect(
          find.byKey(const Key('platform-current-journey-active-companion')),
          findsOneWidget,
        );
        expect(find.text(sample.expectedLabel), findsOneWidget);
        expect(find.bySemanticsLabel(sample.expectedLabel), findsOneWidget);
        if (sample.petId != 'spark-v1') {
          expect(find.text('Active companion: Spark'), findsNothing);
          expect(find.text('Active companion: Navigator'), findsNothing);
          expect(find.text('Active companion: Moss'), findsNothing);
        }
        if (sample.petId == 'spark-v1') {
          expect(find.textContaining(sample.serverName), findsNothing);
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('English journal preserves immutable decision literals', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _LocalizedPlatformApp(
        locale: const Locale('en'),
        child: PlatformScreen(
          loader: () async => platformSnapshot(),
          homeLoader: () async => _homeWithPersistedDecision(
            withDecisionRewards: true,
            unlockedEvent: _readyEvent(
              eventId: 'echo-vault-v1',
              title: 'Literal server vault',
              summary: 'Literal server vault summary',
              choices: <HomeEventChoice>[
                _eventChoice('stabilize-core'),
                _eventChoice('locked', availability: 'LOCKED'),
                _eventChoice('follow-echo'),
              ],
            ),
          ),
          recordExperimentExposures: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Route decisions'), findsOneWidget);
    expect(find.text('Journey in progress'), findsOneWidget);
    expect(find.bySemanticsLabel('Journey in progress'), findsOneWidget);
    expect(find.text('Current point: Outer Beacon'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Current point: Outer Beacon'),
      findsOneWidget,
    );
    expect(find.text('ENERGY progress: 0 of 30'), findsOneWidget);
    expect(find.bySemanticsLabel('ENERGY progress: 0 of 30'), findsOneWidget);
    expect(find.text('Current event: Echo Vault'), findsOneWidget);
    expect(
      find.text(
        'About event: Beyond the gate lies an archive of routes. Its core is '
        'unstable, and the companion hears a call from the depths.',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Current event: Echo Vault. About event: Beyond the gate lies an '
        'archive of routes. Its core is unstable, and the companion hears a '
        'call from the depths.\n2 choices available\n'
        'Available choice: Stabilize the core\n'
        'About choice: The Navigator will lock the resonance and extract safe '
        'fragments.\nChoice rewards: +0 XP · +0 bond\n'
        'Available choice: Follow the echo\n'
        'About choice: The companion will lead the team along a living trail '
        'deep in the archive.\nChoice rewards: +0 XP · +0 bond',
      ),
      findsOneWidget,
    );
    expect(find.text('2 choices available'), findsOneWidget);
    expect(find.text('Available choice: Stabilize the core'), findsOneWidget);
    expect(
      find.text(
        'About choice: The Navigator will lock the resonance and extract safe '
        'fragments.',
      ),
      findsOneWidget,
    );
    expect(find.text('Available choice: Follow the echo'), findsOneWidget);
    expect(
      find.text(
        'About choice: The companion will lead the team along a living trail '
        'deep in the archive.',
      ),
      findsOneWidget,
    );
    expect(find.text('Choice rewards: +0 XP · +0 bond'), findsNWidgets(2));
    expect(find.textContaining('Literal choice locked'), findsNothing);
    final Finder latest = find.byKey(
      const Key('platform-current-journey-latest-decision'),
    );
    expect(latest, findsOneWidget);
    final Finder journeyStartedAt = find.byKey(
      const Key('platform-current-journey-started-at'),
    );
    final String startedAt = _formattedJourneyStartTime(
      tester,
      journeyStartedAt,
      '2026-08-19T09:15:00Z',
      russian: false,
    );
    expect(find.text(startedAt), findsOneWidget);
    expect(find.bySemanticsLabel(startedAt), findsOneWidget);
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
    expect(
      find.descendant(of: decision, matching: find.text(resolvedAt)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: latest, matching: find.text('Latest saved decision')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: latest,
        matching: find.text('Chosen: Сохранённый выбор'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: latest,
        matching: find.text('Сигнал прошлого → Сохранённый исход'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: latest,
        matching: find.text('Result: Сохранённое описание.'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: latest,
        matching: find.text(
          'Rewards: +27 pilot XP; Navigator · +8 bond; +3 Signal glass',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Latest saved decision in the current journey. Сигнал прошлого. Choice: Сохранённый выбор. '
        'Outcome: Сохранённый исход. Result: Сохранённое описание. '
        '$resolvedAt. Rewards: +27 pilot XP; Navigator: +8 bond; '
        '+3 Signal glass.',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Entry 1 of 1. Сигнал прошлого. Decision: Сохранённый выбор. '
        'Outcome: Сохранённый исход. Сохранённое описание. $resolvedAt. '
        'Rewards: +27 pilot XP; Navigator: +8 bond; +3 Signal glass.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'latest current journey decision reflows in English at compact large text',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final SemanticsHandle semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        _LocalizedPlatformApp(
          locale: const Locale('en'),
          textScale: 1.6,
          child: PlatformScreen(
            loader: () async => platformSnapshot(),
            homeLoader: () async => _homeWithPersistedDecision(
              withDecisionRewards: true,
              unlockedEvent: _readyEvent(
                eventId: 'echo-vault-v1',
                title: 'Literal server vault',
                summary: 'Literal server vault summary',
                choices: <HomeEventChoice>[
                  _eventChoice('stabilize-core'),
                  _eventChoice('locked', availability: 'LOCKED'),
                  _eventChoice('follow-echo'),
                ],
              ),
            ),
            recordExperimentExposures: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Finder log = find.byKey(const Key('platform-journey-decision-log'));
      await _bringIntoView(tester, log);
      expect(
        find.byKey(const Key('platform-current-journey-decision-count')),
        findsOneWidget,
      );
      expect(find.text('Decisions made: 1'), findsOneWidget);
      expect(find.bySemanticsLabel('Decisions made: 1'), findsNothing);
      expect(find.text('Journey in progress'), findsOneWidget);
      expect(find.bySemanticsLabel('Journey in progress'), findsOneWidget);
      expect(find.text('Current point: Outer Beacon'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Current point: Outer Beacon'),
        findsOneWidget,
      );
      expect(find.text('ENERGY progress: 0 of 30'), findsOneWidget);
      expect(find.bySemanticsLabel('ENERGY progress: 0 of 30'), findsOneWidget);
      expect(find.text('Current event: Echo Vault'), findsOneWidget);
      expect(
        find.text(
          'About event: Beyond the gate lies an archive of routes. Its core '
          'is unstable, and the companion hears a call from the depths.',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Current event: Echo Vault. About event: Beyond the gate lies an '
          'archive of routes. Its core is unstable, and the companion hears a '
          'call from the depths.\n2 choices available\n'
          'Available choice: Stabilize the core\n'
          'About choice: The Navigator will lock the resonance and extract '
          'safe fragments.\nChoice rewards: +0 XP · +0 bond\n'
          'Available choice: Follow the echo\n'
          'About choice: The companion will lead the team along a living '
          'trail deep in the archive.\nChoice rewards: +0 XP · +0 bond',
        ),
        findsOneWidget,
      );
      expect(find.text('2 choices available'), findsOneWidget);
      expect(
        find.byKey(
          const Key(
            'platform-current-journey-ready-event-choice-stabilize-core',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key(
            'platform-current-journey-ready-event-choice-stabilize-core-'
            'rewards',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key(
            'platform-current-journey-ready-event-choice-follow-echo-rewards',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key('platform-current-journey-ready-event-choice-follow-echo'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key(
            'platform-current-journey-ready-event-choice-stabilize-core-'
            'description',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key(
            'platform-current-journey-ready-event-choice-follow-echo-'
            'description',
          ),
        ),
        findsOneWidget,
      );
      final Finder latest = find.byKey(
        const Key('platform-current-journey-latest-decision'),
      );
      await _bringIntoView(tester, latest);
      final Finder journeyStartedAt = find.byKey(
        const Key('platform-current-journey-started-at'),
      );
      final String startedAt = _formattedJourneyStartTime(
        tester,
        journeyStartedAt,
        '2026-08-19T09:15:00Z',
        russian: false,
      );
      expect(find.text(startedAt), findsOneWidget);
      expect(find.bySemanticsLabel(startedAt), findsOneWidget);
      final String resolvedAt = _formattedDecisionTime(
        tester,
        latest,
        '2026-08-19T10:00:00Z',
        russian: false,
      );
      expect(
        find.descendant(
          of: latest,
          matching: find.text('Latest saved decision'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: latest,
          matching: find.text('Chosen: Сохранённый выбор'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: latest,
          matching: find.text('Сигнал прошлого → Сохранённый исход'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: latest,
          matching: find.text('Result: Сохранённое описание.'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: latest,
          matching: find.text(
            'Rewards: +27 pilot XP; Navigator · +8 bond; +3 Signal glass',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Latest saved decision in the current journey. Сигнал прошлого. Choice: Сохранённый выбор. '
          'Outcome: Сохранённый исход. Result: Сохранённое описание. '
          '$resolvedAt. Rewards: +27 pilot XP; Navigator: +8 bond; '
          '+3 Signal glass.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      semantics.dispose();
    },
  );

  testWidgets(
    'current journey node landmark follows Home identity at compact large text',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final SemanticsHandle semantics = tester.ensureSemantics();
      const List<HomeExpeditionRouteNode> routeDecoy =
          <HomeExpeditionRouteNode>[
            HomeExpeditionRouteNode(
              nodeId: 'lumen-gate',
              nodeName: 'Literal route terminal',
              state: 'COMPLETED',
            ),
          ];

      for (final _NodeLandmarkLocaleSample sample
          in <_NodeLandmarkLocaleSample>[
            (
              landmarkSemantics: 'Current node “Outer Beacon”',
              locale: const Locale('en'),
              nodeName: 'Outer Beacon',
              positionLabel: 'Current point: Outer Beacon',
            ),
            (
              landmarkSemantics: 'Текущий узел «Внешний маяк»',
              locale: const Locale('ru'),
              nodeName: 'Внешний маяк',
              positionLabel: 'Текущая точка: Внешний маяк',
            ),
          ]) {
        await tester.pumpWidget(
          _LocalizedPlatformApp(
            locale: sample.locale,
            textScale: 1.6,
            child: PlatformScreen(
              loader: () async => platformSnapshot(weeklyRouteProgress: 100),
              homeLoader: () async => _homeWithPersistedDecision(
                currentNodeId: 'outer-beacon',
                currentNodeName: 'Literal server beacon',
                routeTrail: routeDecoy,
              ),
              recordExperimentExposures: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final Finder landmarkFinder = find.byKey(
          const Key('platform-current-journey-node-landmark'),
        );
        await _bringIntoView(tester, landmarkFinder);
        final ExpeditionNodeSignal landmark = tester
            .widget<ExpeditionNodeSignal>(landmarkFinder);
        expect(landmark.nodeId, 'outer-beacon');
        expect(landmark.nodeName, sample.nodeName);
        expect(landmark.completed, isFalse);
        expect(landmark.role, ExpeditionNodeSignalRole.current);
        expect(landmark.markSize, 38);
        expect(
          find.byKey(
            const Key('expedition-node-mark-outer-beacon-outerBeacon'),
          ),
          findsOneWidget,
        );
        expect(find.text(sample.nodeName.toUpperCase()), findsOneWidget);
        expect(find.text(sample.positionLabel), findsOneWidget);
        expect(find.bySemanticsLabel(sample.positionLabel), findsOneWidget);
        expect(find.bySemanticsLabel(sample.landmarkSemantics), findsNothing);
        expect(tester.takeException(), isNull);
      }

      semantics.dispose();
    },
  );

  testWidgets('future current position preserves literal neutral landmark', (
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
          loader: () async => platformSnapshot(weeklyRouteProgress: 100),
          homeLoader: () async => _homeWithPersistedDecision(
            currentNodeId: 'future-signal-v1',
            currentNodeName: 'Literal future signal',
            expeditionStatus: 'COMPLETED',
            routeTrail: const <HomeExpeditionRouteNode>[
              HomeExpeditionRouteNode(
                nodeId: 'outer-beacon',
                nodeName: 'Literal route decoy',
                state: 'CURRENT',
              ),
            ],
          ),
          recordExperimentExposures: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder landmarkFinder = find.byKey(
      const Key('platform-current-journey-node-landmark'),
    );
    await _bringIntoView(tester, landmarkFinder);
    final ExpeditionNodeSignal landmark = tester.widget<ExpeditionNodeSignal>(
      landmarkFinder,
    );
    expect(landmark.nodeId, 'future-signal-v1');
    expect(landmark.nodeName, 'Literal future signal');
    expect(landmark.completed, isTrue);
    expect(landmark.role, ExpeditionNodeSignalRole.current);
    expect(
      find.byKey(const Key('expedition-node-mark-future-signal-v1-unknown')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: landmarkFinder,
        matching: find.byIcon(Icons.flag_outlined),
      ),
      findsOneWidget,
    );
    expect(find.text('LITERAL FUTURE SIGNAL'), findsOneWidget);
    expect(find.text('Current point: Literal future signal'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Current point: Literal future signal'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Current node “Literal future signal”, expedition completed',
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('current journey keeps accepted over-target energy literal', (
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
          loader: () async => platformSnapshot(weeklyRouteProgress: 100),
          homeLoader: () async => _homeWithPersistedDecision(
            expeditionProgress: 37,
            requiredEnergy: 30,
          ),
          recordExperimentExposures: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder progress = find.byKey(
      const Key('platform-current-journey-energy-progress'),
    );
    await _bringIntoView(tester, progress);
    expect(find.text('ENERGY progress: 37 of 30'), findsOneWidget);
    expect(find.bySemanticsLabel('ENERGY progress: 37 of 30'), findsOneWidget);
    final Finder signalFinder = find.byKey(
      const Key('platform-current-journey-expedition-progress-signal'),
    );
    await _bringIntoView(tester, signalFinder);
    final ExpeditionProgressSignal signal = tester
        .widget<ExpeditionProgressSignal>(signalFinder);
    expect(signal.expeditionId, 'starter-expedition-v1');
    expect(signal.progress, 37);
    expect(signal.target, 30);
    expect(
      find.byKey(
        const Key(
          'expedition-progress-signal-starter-expedition-v1-outerBeacon',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: progress,
        matching: find.byType(LinearProgressIndicator),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets(
    'current journey route trail follows ordered Home facts at compact large text',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final SemanticsHandle semantics = tester.ensureSemantics();
      const List<HomeExpeditionRouteNode> acceptedRoute =
          <HomeExpeditionRouteNode>[
            HomeExpeditionRouteNode(
              nodeId: 'outer-beacon',
              nodeName: 'Literal server beacon',
              state: 'VISITED',
              decision: HomeExpeditionRouteDecision(
                choiceId: 'follow-pulse',
                choiceTitle: 'Literal saved choice',
                outcomeTitle: 'Literal saved outcome',
              ),
            ),
            HomeExpeditionRouteNode(
              nodeId: 'lumen-gate',
              nodeName: 'Literal server gate',
              state: 'VISITED',
            ),
            HomeExpeditionRouteNode(
              nodeId: 'future-node-v2',
              nodeName: 'Literal future node',
              state: 'CURRENT',
            ),
          ];

      for (final _RouteTrailLocaleSample sample in <_RouteTrailLocaleSample>[
        (
          countLabel: 'Discovered nodes: 3',
          locale: const Locale('en'),
          nodeNames: <String>[
            'Outer Beacon',
            'Lumen Gate',
            'Literal future node',
          ],
          routeSemantics:
              'Journey route: 3 discovered nodes. Last point: Literal future '
              'node. Accepted decisions: Outer Beacon: Literal saved choice '
              '→ Literal saved outcome.',
        ),
        (
          countLabel: 'Открыто узлов: 3',
          locale: const Locale('ru'),
          nodeNames: <String>[
            'Внешний маяк',
            'Люминовые ворота',
            'Literal future node',
          ],
          routeSemantics:
              'Маршрут похода: открыто узлов — 3. Последняя точка: Literal '
              'future node. Принятые решения: Внешний маяк: Literal saved '
              'choice → Literal saved outcome.',
        ),
      ]) {
        await tester.pumpWidget(
          _LocalizedPlatformApp(
            locale: sample.locale,
            textScale: 1.6,
            child: PlatformScreen(
              loader: () async => platformSnapshot(weeklyRouteProgress: 99),
              homeLoader: () async =>
                  _homeWithPersistedDecision(routeTrail: acceptedRoute),
              recordExperimentExposures: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final Finder routeFinder = find.byKey(
          const Key('platform-current-journey-route-trail'),
        );
        await _bringIntoView(tester, routeFinder);
        final ExpeditionRouteTrail route = tester.widget<ExpeditionRouteTrail>(
          routeFinder,
        );
        expect(
          route.nodes.map((ExpeditionRouteTrailNode node) => node.nodeId),
          <String>['outer-beacon', 'lumen-gate', 'future-node-v2'],
        );
        expect(
          route.nodes.map((ExpeditionRouteTrailNode node) => node.nodeName),
          sample.nodeNames,
        );
        expect(
          route.nodes.map((ExpeditionRouteTrailNode node) => node.state),
          <String>['VISITED', 'VISITED', 'CURRENT'],
        );
        expect(route.nodes.first.decision?.choiceId, 'follow-pulse');
        expect(route.nodes.first.decision?.choiceTitle, 'Literal saved choice');
        expect(
          route.nodes.first.decision?.outcomeTitle,
          'Literal saved outcome',
        );
        expect(
          find.byKey(const Key('platform-current-journey-route-node-count')),
          findsOneWidget,
        );
        expect(find.text(sample.countLabel), findsOneWidget);
        expect(find.bySemanticsLabel(sample.countLabel), findsNothing);
        expect(find.bySemanticsLabel(sample.routeSemantics), findsOneWidget);
        expect(
          find.text('Literal saved choice → Literal saved outcome'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }

      semantics.dispose();
    },
  );

  testWidgets(
    'current journey route trail omits empty Home facts despite Platform decoy',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _LocalizedPlatformApp(
          locale: const Locale('en'),
          textScale: 1.6,
          child: PlatformScreen(
            loader: () async => platformSnapshot(weeklyRouteProgress: 100),
            homeLoader: () async => _homeWithPersistedDecision(
              routeTrail: const <HomeExpeditionRouteNode>[],
            ),
            recordExperimentExposures: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _bringIntoView(
        tester,
        find.byKey(const Key('platform-current-journey-energy-progress')),
      );
      expect(
        find.byKey(const Key('platform-current-journey-route-trail')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('platform-current-journey-route-node-count')),
        findsNothing,
      );
      expect(find.byType(ExpeditionRouteTrail), findsNothing);
      expect(find.text('Trail of this journey'), findsNothing);
      expect(
        find.byKey(const Key('platform-current-journey-latest-decision')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'current journey READY scene follows Home event at compact large text',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final SemanticsHandle semantics = tester.ensureSemantics();

      for (final _EventSceneLocaleSample sample
          in <_EventSceneLocaleSample>[
            (
              locale: const Locale('en'),
              title: 'Signal Source',
              eventLabel: 'Current event: Signal Source',
              summaryLabel: 'About event: The beacon answers with a pulse.',
              fallbackLabel: 'Event scene “Signal Source”',
              sceneLabel:
                  'Event scene “Signal Source”: the outer beacon sends '
                  'repeating pulses through the fog.',
            ),
            (
              locale: const Locale('ru'),
              title: 'Источник сигнала',
              eventLabel: 'Текущее событие: Источник сигнала',
              summaryLabel: 'О событии: Маяк отвечает импульсом.',
              fallbackLabel: 'Сцена события «Источник сигнала»',
              sceneLabel:
                  'Сцена события «Источник сигнала»: внешний маяк посылает '
                  'повторяющиеся импульсы сквозь туман.',
            ),
          ]) {
        await tester.pumpWidget(
          _LocalizedPlatformApp(
            locale: sample.locale,
            textScale: 1.6,
            child: PlatformScreen(
              loader: () async => platformSnapshot(
                resolvedEventCount: 99,
                weeklyRouteProgress: 100,
              ),
              homeLoader: () async => _homeWithPersistedDecision(
                expeditionStatus: 'IN_PROGRESS',
                currentNodeId: 'future-decoy-node-v1',
                currentNodeName: 'Literal decoy node',
                unlockedEvent: _readyEvent(
                  eventId: 'signal-source-v1',
                  title: 'Literal server event',
                  summary: 'Literal server summary',
                ),
              ),
              recordExperimentExposures: false,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final Finder eventFinder = find.byKey(
          const Key('platform-current-journey-ready-event'),
        );
        await _bringIntoView(tester, eventFinder);
        final Finder sceneFinder = find.byKey(
          const Key('platform-current-journey-ready-event-scene'),
        );
        final ExpeditionEventScene scene = tester.widget<ExpeditionEventScene>(
          sceneFinder,
        );
        expect(scene.eventId, 'signal-source-v1');
        expect(scene.eventTitle, sample.title);
        expect(scene.fallbackSemanticLabel, sample.fallbackLabel);
        expect(scene.maxHeight, 144);
        expect(
          find.byKey(const Key('event-scene-signal-source-v1')),
          findsOneWidget,
        );
        expect(find.text(sample.eventLabel), findsOneWidget);
        expect(find.text(sample.summaryLabel), findsOneWidget);
        expect(
          find.bySemanticsLabel(
            '${sample.eventLabel}. ${sample.summaryLabel}',
          ),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel(sample.sceneLabel), findsNothing);
        expect(tester.takeException(), isNull);
      }

      semantics.dispose();
    },
  );

  testWidgets('future ready event preserves literal neutral scene', (
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
          loader: () async => platformSnapshot(
            resolvedEventCount: 99,
            weeklyRouteProgress: 100,
          ),
          homeLoader: () async => _homeWithPersistedDecision(
            expeditionStatus: 'EVENT_READY',
            unlockedEvent: _readyEvent(
              eventId: 'future-event-v1',
              title: 'Literal future event',
              summary: 'Literal future summary',
            ),
          ),
          recordExperimentExposures: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder eventFinder = find.byKey(
      const Key('platform-current-journey-ready-event'),
    );
    await _bringIntoView(tester, eventFinder);
    final Finder sceneFinder = find.byKey(
      const Key('platform-current-journey-ready-event-scene'),
    );
    final ExpeditionEventScene scene = tester.widget<ExpeditionEventScene>(
      sceneFinder,
    );
    expect(scene.eventId, 'future-event-v1');
    expect(scene.eventTitle, 'Literal future event');
    expect(scene.fallbackSemanticLabel, 'Event scene “Literal future event”');
    expect(
      find.byKey(const Key('event-scene-fallback-future-event-v1')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('event-scene-signal-source-v1')), findsNothing);
    expect(find.text('Current event: Literal future event'), findsOneWidget);
    expect(find.text('About event: Literal future summary'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Current event: Literal future event. About event: Literal future '
        'summary',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Event scene “Literal future event”'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('ready choice details, requirements and rewards follow locale', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final _ReadyChoiceLocaleSample sample in <_ReadyChoiceLocaleSample>[
      (
        locale: const Locale('en'),
        knownTitle: 'Available choice: Cross on the first light',
        knownDescription:
            'About choice: Use Steady Step to hold the rhythm of the moving '
            'causeway above the meridian.',
        knownRequirement:
            'Requirement: Unlock Steady Step to cross on the first light.',
        knownReward: 'Choice rewards: +31 XP · +6 bond, +2 Ash Seed',
        lockedTitle: 'Available choice: Share the current with the companion',
        lockedRequirement: 'Requirement: Literal locked requirement',
        lockedReward: 'Choice rewards: +99 XP · +99 bond',
        futureTitle: 'Available choice: Literal future choice',
        futureDescription: 'About choice: Literal future choice description',
        futureRequirement: 'Requirement: Literal future requirement',
        futureReward:
            'Choice rewards: +0 XP · +16 bond, +3 Literal future relic',
      ),
      (
        locale: const Locale('ru'),
        knownTitle: 'Доступный вариант: Перейти по первому свету',
        knownDescription:
            'О варианте: Применить Ровный шаг и удержать ритм подвижного '
            'перехода над меридианом.',
        knownRequirement:
            'Условие: Откройте навык «Ровный шаг», чтобы перейти по первому '
            'свету.',
        knownReward: 'Награды за вариант: +31 XP · +6 связь, +2 Семя пепла',
        lockedTitle: 'Доступный вариант: Разделить поток с питомцем',
        lockedRequirement: 'Условие: Literal locked requirement',
        lockedReward: 'Награды за вариант: +99 XP · +99 связь',
        futureTitle: 'Доступный вариант: Literal future choice',
        futureDescription: 'О варианте: Literal future choice description',
        futureRequirement: 'Условие: Literal future requirement',
        futureReward:
            'Награды за вариант: +0 XP · +16 связь, +3 Literal future relic',
      ),
    ]) {
      await tester.pumpWidget(
        _LocalizedPlatformApp(
          locale: sample.locale,
          textScale: 1.6,
          child: PlatformScreen(
            loader: () async => platformSnapshot(),
            homeLoader: () async => _homeWithPersistedDecision(
              unlockedEvent: _readyEvent(
                eventId: 'dawn-meridian-v1',
                title: 'Literal server meridian',
                summary: 'Literal server meridian summary',
                choices: <HomeEventChoice>[
                  _eventChoice(
                    'plain-choice-v1',
                    title: 'Literal plain choice',
                    description: 'Literal plain choice description',
                  ),
                  _eventChoice(
                    'cross-first-light-causeway',
                    pilotExperienceReward: 31,
                    petBondReward: 6,
                    materialReward: const HomeMaterialRewardPreview(
                      itemId: 'ash-seed',
                      itemName: 'Literal server ash seed',
                      quantity: 2,
                    ),
                    requirement: const HomeChoiceRequirement(
                      type: 'SKILL',
                      slotId: 'PILOT',
                      slotName: 'Literal pilot',
                      itemId: 'steady-step',
                      itemName: 'Literal steady step',
                      description: 'Literal known requirement',
                    ),
                  ),
                  _eventChoice(
                    'share-dawn-flow-with-pet',
                    availability: 'LOCKED',
                    pilotExperienceReward: 99,
                    petBondReward: 99,
                    requirement: const HomeChoiceRequirement(
                      type: 'PET_EVOLUTION',
                      slotId: 'PET',
                      slotName: 'Literal pet',
                      itemId: 'spark-v1',
                      itemName: 'Literal spark',
                      description: 'Literal locked requirement',
                    ),
                  ),
                  _eventChoice(
                    'future-choice-v1',
                    title: 'Literal future choice',
                    description: 'Literal future choice description',
                    pilotExperienceReward: 0,
                    petBondReward: 16,
                    materialReward: const HomeMaterialRewardPreview(
                      itemId: 'future-relic-v1',
                      itemName: 'Literal future relic',
                      quantity: 3,
                    ),
                    requirement: const HomeChoiceRequirement(
                      type: 'FUTURE_REQUIREMENT',
                      slotId: 'FUTURE',
                      slotName: 'Literal future slot',
                      itemId: 'future-item-v1',
                      itemName: 'Literal future item',
                      description: 'Literal future requirement',
                    ),
                  ),
                ],
              ),
            ),
            recordExperimentExposures: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _bringIntoView(
        tester,
        find.byKey(const Key('platform-journey-decision-log')),
      );

      expect(find.text(sample.knownTitle), findsOneWidget);
      expect(find.text(sample.knownDescription), findsOneWidget);
      expect(find.text(sample.knownRequirement), findsOneWidget);
      expect(find.text(sample.knownReward), findsOneWidget);
      expect(find.text(sample.lockedTitle), findsNothing);
      expect(find.text(sample.lockedRequirement), findsNothing);
      expect(find.text(sample.lockedReward), findsNothing);
      expect(find.text(sample.futureTitle), findsOneWidget);
      expect(find.text(sample.futureDescription), findsOneWidget);
      expect(find.text(sample.futureRequirement), findsOneWidget);
      expect(find.text(sample.futureReward), findsOneWidget);
      expect(
        find.byKey(
          const Key(
            'platform-current-journey-ready-event-choice-plain-choice-v1-'
            'requirement',
          ),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          const Key(
            'platform-current-journey-ready-event-choice-'
            'cross-first-light-causeway-requirement',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key(
            'platform-current-journey-ready-event-choice-'
            'share-dawn-flow-with-pet-requirement',
          ),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          const Key(
            'platform-current-journey-ready-event-choice-'
            'future-choice-v1-requirement',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          RegExp(
            '${RegExp.escape(sample.knownTitle)}\\n'
            '${RegExp.escape(sample.knownDescription)}\\n'
            '${RegExp.escape(sample.knownRequirement)}\\n'
            '${RegExp.escape(sample.knownReward)}\\n'
            '${RegExp.escape(sample.futureTitle)}\\n'
            '${RegExp.escape(sample.futureDescription)}\\n'
            '${RegExp.escape(sample.futureRequirement)}\\n'
            '${RegExp.escape(sample.futureReward)}\$',
          ),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('ready event omits empty and locked-only choice counts', (
    WidgetTester tester,
  ) async {
    for (final List<HomeEventChoice> choices in <List<HomeEventChoice>>[
      const <HomeEventChoice>[],
      <HomeEventChoice>[
        _eventChoice(
          'locked',
          availability: 'LOCKED',
          requirement: const HomeChoiceRequirement(
            type: 'FUTURE_REQUIREMENT',
            slotId: 'FUTURE',
            slotName: 'Literal future slot',
            itemId: 'future-item-v1',
            itemName: 'Literal future item',
            description: 'Literal locked requirement',
          ),
        ),
      ],
    ]) {
      await tester.pumpWidget(
        _LocalizedPlatformApp(
          locale: const Locale('en'),
          child: PlatformScreen(
            loader: () async => platformSnapshot(),
            homeLoader: () async => _homeWithPersistedDecision(
              unlockedEvent: _readyEvent(choices: choices),
            ),
            recordExperimentExposures: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const Key('platform-current-journey-ready-event-choice-count'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          const Key(
            'platform-current-journey-ready-event-choice-locked-rewards',
          ),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          const Key(
            'platform-current-journey-ready-event-choice-locked-requirement',
          ),
        ),
        findsNothing,
      );
    }
  });

  testWidgets('non-ready current event is omitted fail-closed', (
    WidgetTester tester,
  ) async {
    for (final String status in <String>['RESOLVED', 'FUTURE']) {
      await tester.pumpWidget(
        _LocalizedPlatformApp(
          locale: const Locale('en'),
          child: PlatformScreen(
            loader: () async => platformSnapshot(resolvedEventCount: 99),
            homeLoader: () async => _homeWithPersistedDecision(
              expeditionStatus: 'EVENT_READY',
              unlockedEvent: _readyEvent(
                status: status,
                choices: <HomeEventChoice>[
                  _eventChoice(
                    'available',
                    requirement: const HomeChoiceRequirement(
                      type: 'FUTURE_REQUIREMENT',
                      slotId: 'FUTURE',
                      slotName: 'Literal future slot',
                      itemId: 'future-item-v1',
                      itemName: 'Literal future item',
                      description: 'Literal non-ready requirement',
                    ),
                  ),
                ],
              ),
            ),
            recordExperimentExposures: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('platform-current-journey-ready-event')),
        findsNothing,
      );
      expect(find.byType(ExpeditionEventScene), findsNothing);
      expect(
        find.byKey(
          const Key(
            'platform-current-journey-ready-event-choice-available-rewards',
          ),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          const Key(
            'platform-current-journey-ready-event-choice-'
            'available-requirement',
          ),
        ),
        findsNothing,
      );
    }
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
  bool withDecisionRewards = false,
  String? currentNodeId,
  String? currentNodeName,
  String? expeditionId,
  String? expeditionName,
  int? expeditionProgress,
  String? expeditionStatus,
  bool legacyPilotId = false,
  bool legacyPilotProgression = false,
  String? pilotId,
  int? pilotCurrentExperience,
  int? pilotLevel,
  String? pilotName,
  int? pilotNextLevelExperience,
  bool legacyPetId = false,
  bool missingPetEvolutionStage = false,
  bool missingPetSpecies = false,
  int? petBond,
  int? petEvolutionStage,
  String? petId,
  int? petLevel,
  String? petName,
  String? petSpecies,
  List<HomeExpeditionRouteNode>? routeTrail,
  int? requiredEnergy,
  HomeExpeditionEvent? unlockedEvent,
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
    expeditionId: expeditionId ?? demo.expeditionId,
    expeditionName: expeditionName ?? demo.expeditionName,
    currentNodeId: currentNodeId ?? demo.currentNodeId,
    currentNodeName: currentNodeName ?? demo.currentNodeName,
    expeditionProgress: expeditionProgress ?? demo.expeditionProgress,
    requiredEnergy: requiredEnergy ?? demo.requiredEnergy,
    expeditionStatus:
        expeditionStatus ??
        (completionRecap == null ? demo.expeditionStatus : 'COMPLETED'),
    expeditionVersion: demo.expeditionVersion,
    expeditionJourneyNumber: 7,
    journeyStartedAt: '2026-08-19T09:15:00Z',
    routeTrail: routeTrail ?? demo.routeTrail,
    decisionLog: <HomeExpeditionDecisionLogEntry>[
      HomeExpeditionDecisionLogEntry(
        eventId: 'legacy-event-v1',
        eventTitle: 'Сигнал прошлого',
        choiceId: 'legacy-choice',
        choiceTitle: 'Сохранённый выбор',
        outcomeTitle: 'Сохранённый исход',
        outcomeSummary: 'Сохранённое описание.',
        resolvedAt: '2026-08-19T10:00:00Z',
        pilotExperienceGained: withDecisionRewards ? 27 : 0,
        petId: withDecisionRewards ? 'navigator-v1' : null,
        petName: withDecisionRewards ? 'Navigator' : null,
        petBondGained: withDecisionRewards ? 8 : 0,
        materialReward: withDecisionRewards
            ? const HomeJourneyMaterialReward(
                itemId: 'signal-glass',
                itemName: 'Signal glass',
                quantity: 3,
              )
            : null,
      ),
    ],
    completionRecap: completionRecap,
    recentJourneyRecaps: recentJourneyRecaps,
    journeyChronicle: journeyChronicle,
    unlockedEvent: unlockedEvent ?? demo.unlockedEvent,
    pilotId: legacyPilotId ? null : pilotId ?? demo.pilotId,
    pilotName: pilotName ?? demo.pilotName,
    pilotLevel: pilotLevel ?? demo.pilotLevel,
    pilotCurrentExperience: legacyPilotProgression
        ? 0
        : pilotCurrentExperience ?? demo.pilotCurrentExperience,
    pilotNextLevelExperience: legacyPilotProgression
        ? 0
        : pilotNextLevelExperience ?? demo.pilotNextLevelExperience,
    petId: legacyPetId ? null : petId ?? demo.petId,
    petName: petName ?? demo.petName,
    petSpecies: missingPetSpecies ? null : petSpecies ?? demo.petSpecies,
    petLevel: petLevel ?? demo.petLevel,
    petBond: petBond ?? demo.petBond,
    petEvolutionStage: missingPetEvolutionStage
        ? null
        : petEvolutionStage ?? demo.petEvolutionStage,
    dailyGoalPolicy: demo.dailyGoalPolicy,
  );
}

HomeExpeditionEvent _readyEvent({
  String eventId = 'signal-source-v1',
  String title = 'Literal server event',
  String summary = 'Literal server summary',
  String status = 'READY',
  List<HomeEventChoice> choices = const <HomeEventChoice>[],
}) {
  return HomeExpeditionEvent(
    eventId: eventId,
    title: title,
    summary: summary,
    status: status,
    choices: choices,
  );
}

HomeEventChoice _eventChoice(
  String choiceId, {
  String availability = 'AVAILABLE',
  String? description,
  HomeMaterialRewardPreview? materialReward,
  HomeChoiceRequirement? requirement,
  int petBondReward = 0,
  int pilotExperienceReward = 0,
  String? title,
}) {
  return HomeEventChoice(
    choiceId: choiceId,
    title: title ?? 'Literal choice $choiceId',
    description: description ?? 'Literal choice description $choiceId',
    pilotExperienceReward: pilotExperienceReward,
    petBondReward: petBondReward,
    materialReward: materialReward,
    availability: availability,
    requirement: requirement,
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

String _formattedJourneyStartTime(
  WidgetTester tester,
  Finder anchor,
  String startedAt, {
  required bool russian,
}) {
  final BuildContext context = tester.element(anchor);
  final MaterialLocalizations materialL10n = MaterialLocalizations.of(context);
  final DateTime journeyStart = DateTime.parse(startedAt).toLocal();
  final String date = materialL10n.formatMediumDate(journeyStart);
  final String time = materialL10n.formatTimeOfDay(
    TimeOfDay.fromDateTime(journeyStart),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  return russian ? 'Начат $date в $time' : 'Started on $date at $time';
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
