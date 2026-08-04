import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/app/main_navigation_shell.dart';
import 'package:walking_rpg_mobile/core/cache/read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/design_system/chapter_vista.dart';
import 'package:walking_rpg_mobile/design_system/character_cosmetics.dart';
import 'package:walking_rpg_mobile/design_system/companion_growth.dart';
import 'package:walking_rpg_mobile/design_system/companion_portrait.dart';
import 'package:walking_rpg_mobile/design_system/expedition_read_state.dart';
import 'package:walking_rpg_mobile/design_system/expedition_ui.dart';
import 'package:walking_rpg_mobile/design_system/pilot_portrait.dart';
import 'package:walking_rpg_mobile/design_system/progression_sigil.dart';
import 'package:walking_rpg_mobile/design_system/quest_route_signal.dart';
import 'package:walking_rpg_mobile/design_system/squad_formation_signal.dart';
import 'package:walking_rpg_mobile/design_system/weekly_route_signal.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';
import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';
import 'package:walking_rpg_mobile/features/platform/data/platform_api_client.dart';
import 'package:walking_rpg_mobile/features/platform/domain/platform_command_result.dart';
import 'package:walking_rpg_mobile/features/platform/domain/platform_snapshot.dart';
import 'package:walking_rpg_mobile/features/platform/presentation/platform_screen.dart';

import 'support/platform_fixture.dart';

void main() {
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
  });

  testWidgets('journal retries without exposing stale actions after error', (
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
    expect(find.textContaining('Backend недоступен'), findsOneWidget);

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
    semantics.dispose();
  });

  testWidgets('keeps server progression copy beside exact visual identities', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final PlatformSnapshot initial = platformSnapshot(
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
      find.bySemanticsLabel('Прогресс задания «Исследователь»: 2 из 3'),
      findsOneWidget,
    );

    final Finder unlockedAchievement = find.byKey(
      const Key('platform-achievement-onboarding-complete'),
    );
    await _bringIntoView(tester, unlockedAchievement);
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
      Key('platform-weekly-route-compact'),
      Key('weekly-route-signal-weekly-route-1-firstSignal'),
      Key('platform-pet-compact-spark-v1'),
      Key('platform-skill-compact-steady-step'),
      Key('platform-quest-compact-walk-3000'),
      Key('quest-route-signal-walk-3000-steps'),
      Key('platform-squad-empty-compact'),
      Key('squad-formation-signal-open-0'),
      Key('platform-cosmetic-compact-pilot-scarf'),
      Key('platform-achievement-onboarding-complete'),
      Key('platform-journal-footer'),
    ]) {
      final Finder target = find.byKey(key);
      await _bringIntoView(tester, target);
      expect(target, findsOneWidget);
      _expectNoLayoutException(tester);
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

  testWidgets('shows backend message instead of exception internals', (
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
      find.text('Не удалось выполнить действие: Недостаточно сезонного опыта'),
      findsOneWidget,
    );
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
        'Экипаж маршрута: пилот Навигатор и Искра. '
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
    expect(
      find.bySemanticsLabel('Рост спутника: Малыш, этап 1 из 3'),
      findsWidgets,
    );
    expect(
      find.bySemanticsLabel(
        'Искра, люмин, Малыш · форма 1, активный спутник, Ореол Искры',
      ),
      findsOneWidget,
    );

    final Finder pilotPreview = find.byKey(
      const Key('platform-cosmetic-preview-pilot-scarf'),
    );
    await _bringIntoView(tester, pilotPreview);
    final PilotPortrait scarf = tester.widget<PilotPortrait>(pilotPreview);
    expect(scarf.hasNavigatorScarf, isTrue);
    expect(scarf.illustrationAsset, PilotPortrait.scarfAssetPath);
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

Future<void> _bringIntoView(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
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
