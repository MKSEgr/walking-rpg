import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/app/main_navigation_shell.dart';
import 'package:walking_rpg_mobile/core/cache/read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/design_system/chapter_vista.dart';
import 'package:walking_rpg_mobile/design_system/companion_growth.dart';
import 'package:walking_rpg_mobile/design_system/companion_motion.dart';
import 'package:walking_rpg_mobile/design_system/equipment_mount_signal.dart';
import 'package:walking_rpg_mobile/design_system/expedition_item_art.dart';
import 'package:walking_rpg_mobile/design_system/expedition_node_signal.dart';
import 'package:walking_rpg_mobile/design_system/expedition_read_state.dart';
import 'package:walking_rpg_mobile/design_system/expedition_route_trail.dart';
import 'package:walking_rpg_mobile/design_system/expedition_ui.dart';
import 'package:walking_rpg_mobile/design_system/pilot_motion.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';
import 'package:walking_rpg_mobile/features/crafting/domain/crafting_result.dart';
import 'package:walking_rpg_mobile/features/equipment/domain/equipment_result.dart';
import 'package:walking_rpg_mobile/features/event/domain/event_resolution_result.dart';
import 'package:walking_rpg_mobile/features/expedition/domain/expedition_advance_result.dart';
import 'package:walking_rpg_mobile/features/expedition/domain/expedition_journey_result.dart';
import 'package:walking_rpg_mobile/features/home/data/home_api_client.dart';
import 'package:walking_rpg_mobile/features/home/domain/daily_goal_policy.dart';
import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';
import 'package:walking_rpg_mobile/features/home/domain/weekly_activity_rhythm.dart';
import 'package:walking_rpg_mobile/features/home/presentation/home_screen.dart';
import 'package:walking_rpg_mobile/features/item_upgrade/domain/item_upgrade_result.dart';
import 'package:walking_rpg_mobile/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('home loading waits for an accepted route snapshot', (
    WidgetTester tester,
  ) async {
    final Completer<HomeSnapshot> loader = Completer<HomeSnapshot>();

    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(loader: () => loader.future)),
    );
    await tester.pump();

    expect(find.byKey(const Key('home-loading-state')), findsOneWidget);
    expect(find.byType(ExpeditionReadState), findsOneWidget);
    expect(find.byType(ExpeditionBackdrop), findsOneWidget);
    expect(find.text('Сверяем маршрут'), findsOneWidget);
    expect(find.byKey(const Key('home-expedition-vista')), findsNothing);

    loader.complete(HomeSnapshot.demo);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-loading-state')), findsNothing);
    expect(find.byKey(const Key('home-expedition-vista')), findsOneWidget);
  });

  testWidgets('home hero uses accepted chapter and companion state', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(loader: () async => HomeSnapshot.demo)),
    );
    await tester.pumpAndSettle();

    final Finder vistaFinder = find.byKey(const Key('home-expedition-vista'));
    expect(vistaFinder, findsOneWidget);
    final ChapterVista vista = tester.widget<ChapterVista>(vistaFinder);
    expect(vista.progress, HomeSnapshot.demo.expeditionProgressValue);
    expect(
      find.bySemanticsLabel(
        'Сигнал из туманного сектора, Внешний маяк, маршрут 0%',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('home-current-node-badge')), findsOneWidget);
    final Finder nodeSignal = find.byType(ExpeditionNodeSignal);
    expect(nodeSignal, findsOneWidget);
    final ExpeditionNodeSignal signal = tester.widget<ExpeditionNodeSignal>(
      nodeSignal,
    );
    expect(signal.nodeId, 'outer-beacon');
    expect(signal.nodeName, 'Внешний маяк');
    expect(signal.completed, isFalse);
    expect(
      find.byKey(const Key('expedition-node-mark-outer-beacon-outerBeacon')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Текущий узел «Внешний маяк»'),
      findsOneWidget,
    );
    expect(find.byType(ExpeditionRouteTrail), findsOneWidget);
    expect(find.text('След этого похода'), findsOneWidget);
    expect(
      find.byKey(const Key('expedition-route-node-outer-beacon-current')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Маршрут похода: открыто узлов — 1. '
        'Последняя точка: Внешний маяк.',
      ),
      findsOneWidget,
    );
    final Finder companionBadge = find.byKey(
      const Key('home-active-companion-badge'),
    );
    expect(companionBadge, findsOneWidget);
    expect(
      find.descendant(of: companionBadge, matching: find.text('ИСКРА · УР. 1')),
      findsOneWidget,
    );
    final Finder portraitFinder = find.byKey(
      const Key('home-active-companion-portrait'),
    );
    expect(portraitFinder, findsOneWidget);
    final CompanionMotionPortrait portrait = tester
        .widget<CompanionMotionPortrait>(portraitFinder);
    expect(portrait.petId, 'spark-v1');
    expect(portrait.evolutionStage, 0);
    expect(portrait.hasMotionAsset, isTrue);
    expect(find.byType(PilotMotionPortrait), findsOneWidget);
    expect(find.byKey(const Key('home-pilot-motion-portrait')), findsOneWidget);
    expect(
      find.byKey(const Key('pilot-motion-frame-navigator-v1-0-5')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Пилот Навигатор'), findsNothing);
    expect(
      find.byKey(const Key('home-team-companion-portrait')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('companion-illustration-spark-v1-stage-0')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Искра, люмин, Малыш · форма 1, активный спутник'),
      findsOneWidget,
    );
    expect(find.byType(CompanionGrowthTrack), findsOneWidget);
    expect(
      find.bySemanticsLabel('Рост спутника: Малыш, этап 1 из 3'),
      findsOneWidget,
    );

    semantics.dispose();
  });

  testWidgets('home maps saved route decisions without joining the log', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(loader: () async => _routeWithDecision())),
    );
    await tester.pumpAndSettle();

    final ExpeditionRouteTrail trail = tester.widget<ExpeditionRouteTrail>(
      find.byType(ExpeditionRouteTrail),
    );
    expect(trail.nodes.first.decision?.choiceId, 'follow-pulse');
    expect(trail.nodes.first.decision?.choiceTitle, 'Пойти за импульсом');
    expect(trail.nodes.first.decision?.outcomeTitle, 'Найден маяк');
    expect(trail.nodes.last.decision, isNull);
    expect(
      find.byKey(const Key('expedition-route-decision-outer-beacon')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Маршрут похода: открыто узлов — 2. '
        'Последняя точка: Люминовые ворота. '
        'Принятые решения: Внешний маяк: Пойти за импульсом → '
        'Найден маяк.',
      ),
      findsOneWidget,
    );

    semantics.dispose();
  });

  testWidgets('future current node keeps neutral landmark despite known copy', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        home: HomeScreen(loader: () async => _futureNode()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('expedition-node-signal-future-node-v2-unknown')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('expedition-node-mark-future-node-v2-outerBeacon')),
      findsNothing,
    );
    expect(
      find.bySemanticsLabel('Текущий узел «Внешний маяк»'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('home-weekly-activity-qualification')),
      findsNothing,
    );
    expect(find.byKey(const Key('home-daily-goal-stability')), findsNothing);
    expect(tester.takeException(), isNull);

    semantics.dispose();
  });

  testWidgets(
    'legacy cached companion stays textual without guessed identity',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(home: HomeScreen(loader: () async => _readyToAdvance())),
      );
      await tester.pumpAndSettle();

      final Finder companionBadge = find.byKey(
        const Key('home-active-companion-badge'),
      );
      expect(companionBadge, findsOneWidget);
      expect(
        find.byKey(const Key('home-active-companion-portrait')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: companionBadge,
          matching: find.text('ИСКРА · УР. 1'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('home screen renders loaded backend snapshot', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    bool recoveryOpened = false;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomeScreen(
          loader: () async => HomeSnapshot.demo,
          recoveryCount: 1,
          onOpenRecovery: () {
            recoveryOpened = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home-command-recovery')));
    expect(recoveryOpened, isTrue);
    expect(find.text('Сегодня: 0 / 6000'), findsOneWidget);
    expect(find.text('До личной цели осталось 6000 шагов'), findsOneWidget);
    const String russianGoalStability =
        'Принятые сегодня шаги не повышают сегодняшнюю цель · '
        'они могут учитываться в следующих личных целях';
    expect(find.text(russianGoalStability), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Сегодня: 0 / 6000. До личной цели осталось 6000 шагов. '
        '$russianGoalStability',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Ритм недели: активных дней — 0 · цель 4'),
      findsOneWidget,
    );
    expect(
      find.text(
        'До мягкой цели в окне из 7 дней осталось 4 активных дня · '
        'отдых не сбрасывает прогресс',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Любая принятая активность делает день ритма активным · '
        'личная цель считается отдельно',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('home-weekly-activity-rhythm-progress')),
      findsOneWidget,
    );
    final Text russianDateRange = tester.widget<Text>(
      find.byKey(const Key('home-weekly-activity-date-range')),
    );
    final MaterialLocalizations russianMaterialLocalizations =
        MaterialLocalizations.of(tester.element(find.byType(HomeScreen)));
    expect(
      russianDateRange.data,
      'Учитываются даты: '
      '${russianMaterialLocalizations.formatShortDate(DateTime(2026, 7, 20))}–'
      '${russianMaterialLocalizations.formatShortDate(DateTime(2026, 7, 26))}',
    );
    final Text todayStatus = tester.widget<Text>(
      find.byKey(const Key('home-weekly-activity-today-status')),
    );
    expect(todayStatus.data, startsWith('Сегодня, '));
    expect(todayStatus.data, endsWith(': день отдыха'));
    expect(find.text('Навигатор'), findsOneWidget);
    expect(find.text('Искра'), findsOneWidget);
    expect(
      find.textContaining(
        'Стартовая личная цель: собрано 0 из 3 активных дней',
      ),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('home-pilot-card')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    const String russianPilotProgress =
        'XP 20 / 100 · до следующего уровня 80 XP';
    expect(find.text(russianPilotProgress), findsOneWidget);
    expect(find.bySemanticsLabel(russianPilotProgress), findsOneWidget);
    final LinearProgressIndicator russianProgress = tester
        .widget<LinearProgressIndicator>(
          find.byKey(const Key('home-pilot-experience-progress')),
        );
    expect(russianProgress.value, 0.2);
    expect(find.text('Связь 10 · Малыш'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Доступная энергия: 0 · версия 0'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Доступная энергия: 0 · версия 0'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('weekly rhythm exposes one complete English semantic summary', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomeScreen(loader: () async => _readyToAdvance()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Weekly rhythm: 5 active days · goal 4'), findsOneWidget);
    expect(find.text('Personal goal reached'), findsOneWidget);
    expect(find.textContaining('active days remain'), findsNothing);
    const String englishPilotProgress = 'XP 20 / 100 · 80 XP to next level';
    expect(find.text(englishPilotProgress), findsOneWidget);
    final LinearProgressIndicator englishProgress = tester
        .widget<LinearProgressIndicator>(
          find.byKey(const Key('home-pilot-experience-progress')),
        );
    expect(englishProgress.value, 0.2);
    const String englishQualification =
        'Any accepted activity makes a rhythm day active · '
        'your personal goal is separate';
    expect(find.text(englishQualification), findsOneWidget);
    final Text dateRangeText = tester.widget<Text>(
      find.byKey(const Key('home-weekly-activity-date-range')),
    );
    final String dateRange = dateRangeText.data!;
    final MaterialLocalizations englishMaterialLocalizations =
        MaterialLocalizations.of(tester.element(find.byType(HomeScreen)));
    expect(
      dateRange,
      'Dates counted: '
      '${englishMaterialLocalizations.formatShortDate(DateTime(2026, 7, 20))}–'
      '${englishMaterialLocalizations.formatShortDate(DateTime(2026, 7, 26))}',
    );
    expect(
      find.bySemanticsLabel(
        RegExp(
          r'^Weekly rhythm: 5 active days · goal 4\. '
          r'Goal reached · 7-day window · rest days are normal\. '
          '${RegExp.escape(englishQualification)}\\. '
          '${RegExp.escape(dateRange)}\\. '
          r'Days: .*active day.*rest day.*$',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('home-weekly-activity-day-trail')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('home-weekly-activity-day-2026-07-26')),
      findsOneWidget,
    );
    expect(find.text(dateRange), findsOneWidget);
    final Text todayStatus = tester.widget<Text>(
      find.byKey(const Key('home-weekly-activity-today-status')),
    );
    expect(todayStatus.data, startsWith('Today, '));
    expect(todayStatus.data, endsWith(': active day'));
    final Semantics weeklySemantics = tester.widget<Semantics>(
      find.byKey(const Key('home-weekly-activity-rhythm')),
    );
    expect(
      RegExp(
        r'Today, [^.]+: active day',
      ).allMatches(weeklySemantics.properties.label!).length,
      1,
    );
    expect(
      RegExp(
        RegExp.escape(dateRange),
      ).allMatches(weeklySemantics.properties.label!).length,
      1,
    );
    expect(
      RegExp(
        RegExp.escape(englishQualification),
      ).allMatches(weeklySemantics.properties.label!).length,
      1,
    );
    final Container todayMarker = tester.widget<Container>(
      find.byKey(const Key('home-weekly-activity-day-2026-07-26')),
    );
    final Container earlierMarker = tester.widget<Container>(
      find.byKey(const Key('home-weekly-activity-day-2026-07-20')),
    );
    expect((todayMarker.decoration! as BoxDecoration).border, isNotNull);
    expect((earlierMarker.decoration! as BoxDecoration).border, isNull);

    await tester.scrollUntilVisible(
      find.byKey(const Key('home-pilot-card')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(englishPilotProgress), findsOneWidget);
    expect(tester.takeException(), isNull);

    semantics.dispose();
  });

  testWidgets('daily goal feedback localizes remaining and reached states', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    const String russianGoalStability =
        'Принятые сегодня шаги не повышают сегодняшнюю цель · '
        'они могут учитываться в следующих личных целях';
    const String englishGoalStability =
        "Steps accepted today do not raise today's goal · "
        'they can inform later personal goals';

    Future<void> pumpGoal({
      required Locale locale,
      required int dailySteps,
      int dailyGoal = 6000,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeScreen(
            loader: () async =>
                _readyToAdvance(dailySteps: dailySteps, dailyGoal: dailyGoal),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpGoal(locale: const Locale('ru'), dailySteps: 5999);
    const String russianRemaining = 'До личной цели остался 1 шаг';
    expect(find.text(russianRemaining), findsOneWidget);
    expect(find.text(russianGoalStability), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Сегодня: 5999 / 6000. $russianRemaining. $russianGoalStability',
      ),
      findsOneWidget,
    );

    await pumpGoal(locale: const Locale('ru'), dailySteps: 5998);
    expect(find.text('До личной цели осталось 2 шага'), findsOneWidget);

    await pumpGoal(locale: const Locale('ru'), dailySteps: 5995);
    expect(find.text('До личной цели осталось 5 шагов'), findsOneWidget);

    await pumpGoal(locale: const Locale('en'), dailySteps: 5999);
    expect(find.text('1 step remains to your personal goal'), findsOneWidget);

    await pumpGoal(locale: const Locale('en'), dailySteps: 5997);
    const String englishRemaining = '3 steps remain to your personal goal';
    expect(find.text(englishRemaining), findsOneWidget);
    final Semantics dailySummary = tester.widget<Semantics>(
      find.byKey(const Key('home-daily-goal-summary')),
    );
    expect(
      dailySummary.properties.label,
      'Today: 5997 / 6000. $englishRemaining. $englishGoalStability',
    );
    expect(
      RegExp(
        RegExp.escape(englishRemaining),
      ).allMatches(dailySummary.properties.label!).length,
      1,
    );
    expect(
      RegExp(
        RegExp.escape(englishGoalStability),
      ).allMatches(dailySummary.properties.label!).length,
      1,
    );
    expect(find.text(englishGoalStability), findsOneWidget);

    await pumpGoal(locale: const Locale('en'), dailySteps: 6000);
    expect(find.text('Personal goal reached'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Today: 6000 / 6000. Personal goal reached. '
        '$englishGoalStability',
      ),
      findsOneWidget,
    );

    await pumpGoal(locale: const Locale('ru'), dailySteps: 6842);
    expect(find.text('Личная цель достигнута'), findsOneWidget);
    expect(find.textContaining('До личной цели'), findsNothing);
    expect(tester.takeException(), isNull);

    semantics.dispose();
  });

  testWidgets('legacy weekly rhythm omits inferred today status', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          loader: () async => _readyToAdvance(
            weeklyActivityRhythm: const WeeklyActivityRhythm(
              activeDays: 3,
              windowDays: 7,
              targetActiveDays: 4,
              targetReached: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('home-weekly-activity-today-status')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('home-weekly-activity-day-trail')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('home-weekly-activity-date-range')),
      findsNothing,
    );
    const String qualification =
        'Любая принятая активность делает день ритма активным · '
        'личная цель считается отдельно';
    expect(find.text(qualification), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(RegExp.escape(qualification))),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    semantics.dispose();
  });

  testWidgets('weekly rhythm pluralizes gentle RU and EN guidance', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();

    Future<void> pumpRhythm({
      required Locale locale,
      required int activeDays,
      bool todayActive = false,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeScreen(
            loader: () async => _readyToAdvance(
              weeklyActivityRhythm: _weeklyRhythmWithActiveDays(
                activeDays,
                todayActive: todayActive,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpRhythm(locale: const Locale('ru'), activeDays: 3);
    const String russianSingular =
        'До мягкой цели в окне из 7 дней остался 1 активный день · '
        'отдых не сбрасывает прогресс';
    expect(find.text(russianSingular), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(RegExp.escape(russianSingular))),
      findsOneWidget,
    );

    await pumpRhythm(locale: const Locale('ru'), activeDays: 1);
    expect(
      find.text(
        'До мягкой цели в окне из 7 дней осталось 3 активных дня · '
        'отдых не сбрасывает прогресс',
      ),
      findsOneWidget,
    );

    await pumpRhythm(locale: const Locale('en'), activeDays: 3);
    const String englishSingular =
        'One active day remains toward the gentle goal in this 7-day window · '
        'rest days do not reset progress';
    expect(find.text(englishSingular), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(RegExp.escape(englishSingular))),
      findsOneWidget,
    );

    await pumpRhythm(locale: const Locale('en'), activeDays: 1);
    expect(
      find.text(
        '3 active days remain toward the gentle goal in this 7-day window · '
        'rest days do not reset progress',
      ),
      findsOneWidget,
    );
    final Text englishRestStatus = tester.widget<Text>(
      find.byKey(const Key('home-weekly-activity-today-status')),
    );
    expect(englishRestStatus.data, startsWith('Today, '));
    expect(englishRestStatus.data, endsWith(': rest day'));

    await pumpRhythm(
      locale: const Locale('ru'),
      activeDays: 4,
      todayActive: true,
    );
    final Text russianActiveStatus = tester.widget<Text>(
      find.byKey(const Key('home-weekly-activity-today-status')),
    );
    expect(russianActiveStatus.data, startsWith('Сегодня, '));
    expect(russianActiveStatus.data, endsWith(': активный день'));
    expect(tester.takeException(), isNull);

    semantics.dispose();
  });

  testWidgets('weekly day trail reflows on compact enlarged text', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (BuildContext context, Widget? child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          );
        },
        home: HomeScreen(
          loader: () async => _readyToAdvance(
            weeklyActivityRhythm: _weeklyRhythmWithActiveDays(1),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('home-daily-progress-compact')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('home-weekly-activity-day-trail')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('home-weekly-activity-day-2026-07-20')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('home-weekly-activity-day-2026-07-26')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('home-weekly-activity-today-status')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('home-weekly-activity-date-range')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('home-weekly-activity-qualification')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('home-daily-goal-stability')), findsOneWidget);
    expect(find.byKey(const Key('home-daily-goal-feedback')), findsOneWidget);
    expect(
      find.byKey(const Key('home-pilot-experience-progress')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'field kit reuses stable item art across inventory and crafting',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final SemanticsHandle semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          theme: WalkingRpgTheme.dark(),
          home: HomeScreen(loader: () async => _craftingReady()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('item-art-lumen-shard')), findsNWidgets(2));
      expect(find.byKey(const Key('item-art-echo-thread')), findsNWidgets(2));
      expect(find.byType(ExpeditionItemEmblem), findsNWidgets(5));
      expect(
        find.byKey(const Key('item-art-resonance-compass')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('crafting-result-layout-resonance-compass-wide')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key(
            'crafting-assembly-signal-resonance-compass-v1-'
            'resonanceCompass-READY',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('1 рецепт готов к созданию'), findsOneWidget);
      expect(
        find.bySemanticsLabel('1 рецепт готов к созданию'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Люминовый осколок, 2 из 2, материала достаточно',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      semantics.dispose();
    },
  );

  testWidgets('illustrated field kit reflows on compact enlarged text', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
        home: HomeScreen(loader: () async => _craftingReady()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final Finder nodeSignal = find.byKey(
      const Key('expedition-node-signal-ash-orbit-ashOrbit'),
    );
    expect(nodeSignal, findsOneWidget);
    expect(tester.getSize(nodeSignal).width, lessThanOrEqualTo(236));

    await _scrollAboveStickyAction(
      tester,
      find.byKey(const Key('craft-resonance-compass-v1')),
    );

    expect(
      find.byKey(const Key('inventory-item-layout-lumen-shard-compact')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('crafting-result-layout-resonance-compass-compact')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key(
          'crafting-assembly-signal-resonance-compass-v1-'
          'resonanceCompass-READY',
        ),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('home-craftable-recipes')), findsOneWidget);
    expect(find.text('1 рецепт готов к созданию'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'illustrated event keeps both choices reachable on compact text',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final SemanticsHandle semantics = tester.ensureSemantics();

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
          home: HomeScreen(loader: () async => _eventReady()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('event-scene-signal-source-v1')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Сцена события «Источник сигнала»: внешний маяк посылает '
          'повторяющиеся импульсы сквозь туман.',
        ),
        findsOneWidget,
      );
      for (final String choiceId in <String>['analyze-signal', 'trust-spark']) {
        final Finder choice = find.byKey(Key('home-event-choice-$choiceId'));
        await _scrollAboveStickyAction(tester, choice);
        expect(tester.widget<FilledButton>(choice).onPressed, isNotNull);
        expect(tester.takeException(), isNull);
      }

      semantics.dispose();
    },
  );

  testWidgets('authoritative generation reloads home in place', (
    WidgetTester tester,
  ) async {
    int generation = 0;
    int loads = 0;
    late StateSetter setHostState;
    Future<HomeSnapshot> loader() async {
      loads += 1;
      return HomeSnapshot.demo;
    }

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            setHostState = setState;
            return HomeScreen(
              loader: loader,
              authoritativeRefreshGeneration: generation,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(loads, 1);

    setHostState(() {
      generation += 1;
    });
    await tester.pumpAndSettle();

    expect(loads, 2);
    expect(find.text('Walking RPG'), findsOneWidget);
  });

  testWidgets('network home records recipe once after card enters viewport', (
    WidgetTester tester,
  ) async {
    int generation = 0;
    late StateSetter setHostState;
    final List<Map<String, Object?>> payloads = <Map<String, Object?>>[];
    final List<String> keys = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            setHostState = setState;
            return HomeScreen(
              loader: () async => _craftingReady(),
              authoritativeRefreshGeneration: generation,
              impressionRecorder:
                  ({
                    required String commandType,
                    required Map<String, Object?> payload,
                    required String idempotencyKey,
                  }) async {
                    expect(commandType, 'RECORD_COMPASS_IMPRESSION');
                    payloads.add(payload);
                    keys.add(idempotencyKey);
                    return null;
                  },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(payloads, isEmpty);

    await _scrollAboveStickyAction(
      tester,
      find.byKey(const Key('craft-resonance-compass-v1')),
    );

    setHostState(() {
      generation += 1;
    });
    await tester.pumpAndSettle();

    expect(payloads, <Map<String, Object?>>[
      <String, Object?>{
        'impression': 'RECIPE_READY',
        'contentVersion': 'chapter-1-v1',
      },
    ]);
    expect(keys, <String>[
      'compass-impression-chapter-1-v1-'
          'recipe-resonance-compass-v1-1-RECIPE_READY',
    ]);
  });

  testWidgets(
    'recipe behind sticky action is not counted until it is unobscured',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final List<String> impressions = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            loader: () async => _craftingReady(),
            impressionRecorder:
                ({
                  required String commandType,
                  required Map<String, Object?> payload,
                  required String idempotencyKey,
                }) async {
                  impressions.add(payload['impression']! as String);
                  return null;
                },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(impressions, isEmpty);

      final Finder recipeViewport = find.byKey(
        const Key('home-recipe-viewport-resonance-compass-v1'),
      );
      final Finder stickyAction = find.byKey(
        const Key('home-sticky-action-panel'),
      );
      final ScrollPosition position = tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position;
      final double coveredOffset =
          (position.pixels +
                  tester.getTopLeft(recipeViewport).dy -
                  tester.getTopLeft(stickyAction).dy -
                  1)
              .clamp(position.minScrollExtent, position.maxScrollExtent)
              .toDouble();

      position.jumpTo(coveredOffset);
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(recipeViewport).dy,
        greaterThanOrEqualTo(tester.getTopLeft(stickyAction).dy),
      );
      expect(impressions, isEmpty);

      const double visibleExtent = 24;
      position.jumpTo(
        (position.pixels +
                tester.getTopLeft(recipeViewport).dy -
                tester.getTopLeft(stickyAction).dy +
                visibleExtent)
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble(),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getTopLeft(recipeViewport).dy,
        lessThan(tester.getTopLeft(stickyAction).dy),
      );
      expect(impressions, <String>['RECIPE_READY']);
    },
  );

  testWidgets('failed recipe impression retries on authoritative reload', (
    WidgetTester tester,
  ) async {
    int generation = 0;
    int attempts = 0;
    late StateSetter setHostState;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            setHostState = setState;
            return HomeScreen(
              loader: () async => _craftingReady(),
              authoritativeRefreshGeneration: generation,
              impressionRecorder:
                  ({
                    required String commandType,
                    required Map<String, Object?> payload,
                    required String idempotencyKey,
                  }) async {
                    attempts += 1;
                    if (attempts == 1) {
                      throw StateError('temporary telemetry failure');
                    }
                    return null;
                  },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(attempts, 0);

    await _scrollAboveStickyAction(
      tester,
      find.byKey(const Key('craft-resonance-compass-v1')),
    );
    expect(attempts, 1);

    setHostState(() {
      generation += 1;
    });
    await tester.pumpAndSettle();
    await _scrollAboveStickyAction(
      tester,
      find.byKey(const Key('craft-resonance-compass-v1')),
    );

    expect(attempts, 2);
  });

  testWidgets(
    'failed impression from an older request retries the accepted snapshot',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      int generation = 0;
      int attempts = 0;
      late StateSetter setHostState;
      final Completer<Object?> firstAttempt = Completer<Object?>();

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              setHostState = setState;
              return HomeScreen(
                loader: () async => _craftingReady(),
                authoritativeRefreshGeneration: generation,
                impressionRecorder:
                    ({
                      required String commandType,
                      required Map<String, Object?> payload,
                      required String idempotencyKey,
                    }) {
                      attempts += 1;
                      if (attempts == 1) {
                        return firstAttempt.future;
                      }
                      return Future<Object?>.value();
                    },
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(attempts, 1);

      setHostState(() {
        generation += 1;
      });
      await tester.pumpAndSettle();
      expect(attempts, 1);

      firstAttempt.completeError(StateError('old telemetry request failed'));
      await tester.pumpAndSettle();

      expect(attempts, 2);
    },
  );

  testWidgets('superseded home request never records an impression', (
    WidgetTester tester,
  ) async {
    int generation = 0;
    int loads = 0;
    late StateSetter setHostState;
    final Completer<HomeSnapshot> stale = Completer<HomeSnapshot>();
    final Completer<HomeSnapshot> current = Completer<HomeSnapshot>();
    final List<String> impressions = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            setHostState = setState;
            return HomeScreen(
              loader: () {
                loads += 1;
                return loads == 1 ? stale.future : current.future;
              },
              authoritativeRefreshGeneration: generation,
              impressionRecorder:
                  ({
                    required String commandType,
                    required Map<String, Object?> payload,
                    required String idempotencyKey,
                  }) async {
                    impressions.add(payload['impression']! as String);
                    return null;
                  },
            );
          },
        ),
      ),
    );
    expect(loads, 1);

    setHostState(() {
      generation += 1;
    });
    await tester.pump();
    expect(loads, 2);

    stale.complete(_craftingReady());
    await tester.pump();
    expect(impressions, isEmpty);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    current.complete(_craftingCompleted());
    await tester.pumpAndSettle();
    expect(impressions, isEmpty);

    await _scrollAboveStickyAction(
      tester,
      find.byKey(const Key('craft-resonance-compass-v1')),
    );

    expect(impressions, <String>['RECIPE_CRAFTED']);
  });

  testWidgets('hidden home records an accepted snapshot only when visible', (
    WidgetTester tester,
  ) async {
    final Completer<HomeSnapshot> response = Completer<HomeSnapshot>();
    final List<String> impressions = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: MainNavigationShell(
          home: HomeScreen(
            loader: () => response.future,
            impressionRecorder:
                ({
                  required String commandType,
                  required Map<String, Object?> payload,
                  required String idempotencyKey,
                }) async {
                  impressions.add(payload['impression']! as String);
                  return null;
                },
          ),
          platform: const Scaffold(body: Text('journal-content')),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('navigation-platform')));
    await tester.pump();
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 1);
    response.complete(_craftingReady());
    await tester.pumpAndSettle();

    expect(impressions, isEmpty);
    expect(find.text('journal-content'), findsOneWidget);

    await tester.tap(find.byKey(const Key('navigation-home')));
    await tester.pumpAndSettle();
    expect(impressions, isEmpty);

    await _scrollAboveStickyAction(
      tester,
      find.byKey(const Key('craft-resonance-compass-v1')),
    );

    expect(impressions, <String>['RECIPE_READY']);
  });

  testWidgets('covering route defers a visible recipe impression until pop', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final Completer<HomeSnapshot> response = Completer<HomeSnapshot>();
    final List<String> impressions = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            return HomeScreen(
              loader: () => response.future,
              onOpenAccount: () {
                unawaited(
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) => Scaffold(
                        body: Center(
                          child: FilledButton(
                            key: const Key('close-covering-route'),
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Закрыть аккаунт'),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
              impressionRecorder:
                  ({
                    required String commandType,
                    required Map<String, Object?> payload,
                    required String idempotencyKey,
                  }) async {
                    impressions.add(payload['impression']! as String);
                    return null;
                  },
            );
          },
        ),
      ),
    );

    await tester.tap(find.byTooltip('Аккаунт'));
    await tester.pumpAndSettle();
    expect(find.text('Закрыть аккаунт'), findsOneWidget);

    response.complete(_craftingReady());
    await tester.pumpAndSettle();
    expect(impressions, isEmpty);

    await tester.tap(find.byKey(const Key('close-covering-route')));
    await tester.pumpAndSettle();

    expect(impressions, <String>['RECIPE_READY']);
  });

  testWidgets('backgrounded home defers a visible recipe until resume', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    final Completer<HomeSnapshot> response = Completer<HomeSnapshot>();
    final List<String> impressions = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          loader: () => response.future,
          impressionRecorder:
              ({
                required String commandType,
                required Map<String, Object?> payload,
                required String idempotencyKey,
              }) async {
                impressions.add(payload['impression']! as String);
                return null;
              },
        ),
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    response.complete(_craftingReady());
    await tester.pumpAndSettle();
    expect(impressions, isEmpty);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(impressions, <String>['RECIPE_READY']);
  });

  testWidgets('home screen spends energy and reloads unlocked event', (
    WidgetTester tester,
  ) async {
    int loads = 0;
    int? sentEnergy;
    String? sentKey;

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          loader: () async {
            loads += 1;
            return loads == 1 ? _readyToAdvance() : _eventReady();
          },
          idempotencyKeyFactory: () => 'fixed-key',
          advancer:
              ({
                required String expeditionId,
                required int energyToSpend,
                required String idempotencyKey,
              }) async {
                sentEnergy = energyToSpend;
                sentKey = idempotencyKey;
                return _advanceResult();
              },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Личная цель: медиана 3000 шагов за 3 активных '
        'дней +5%',
      ),
      findsOneWidget,
    );

    final Finder advanceButton = find.widgetWithText(
      FilledButton,
      'Потратить 30 энергии',
    );
    await tester.scrollUntilVisible(
      advanceButton,
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(advanceButton);
    await tester.pumpAndSettle();

    expect(sentEnergy, 30);
    expect(sentKey, 'fixed-key');
    expect(loads, 2);
    expect(find.text('Источник сигнала'), findsOneWidget);
    expect(
      find.byKey(const Key('event-scene-signal-source-v1')),
      findsOneWidget,
    );

    final Finder eventStateButton = find.widgetWithText(
      FilledButton,
      'Выберите решение события',
    );
    await tester.scrollUntilVisible(
      eventStateButton,
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    expect(eventStateButton, findsOneWidget);
  });

  testWidgets('English advance feedback resolves an unlocked event by ID', (
    WidgetTester tester,
  ) async {
    int loads = 0;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomeScreen(
          loader: () async {
            loads += 1;
            return loads == 1 ? _readyToAdvance() : _eventReady();
          },
          advancer:
              ({
                required String expeditionId,
                required int energyToSpend,
                required String idempotencyKey,
              }) async {
                return _advanceResult(
                  unlockedEvent: const ExpeditionEventResult(
                    eventId: 'mirror-delta-v1',
                    title: 'Раздвоенный сигнал',
                    summary: 'Два сигнала ведут к разным берегам.',
                    status: 'READY',
                  ),
                );
              },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder advanceButton = find.widgetWithText(
      FilledButton,
      'Spend 30 ENERGY',
    );
    await _scrollAboveStickyAction(tester, advanceButton);
    await tester.tap(advanceButton);
    await tester.pumpAndSettle();

    expect(find.text('Event unlocked: Split Signal'), findsOneWidget);
    expect(loads, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'English Home resolves current catalog and ingredient semantics',
    (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeScreen(loader: () async => _craftingReady()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Signal from the Fog Sector'), findsOneWidget);
      expect(find.bySemanticsLabel('Current node “Ash Orbit”'), findsOneWidget);

      final Finder craftButton = find.byKey(
        const Key('craft-resonance-compass-v1'),
      );
      await tester.scrollUntilVisible(
        craftButton,
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lumen Shard × 2'), findsOneWidget);
      expect(find.text('Assemble a Resonance Compass'), findsOneWidget);
      expect(
        find.text('Bind the light core to the living route thread.'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Lumen Shard, 2 of 2, enough materials'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      semantics.dispose();
    },
  );

  testWidgets('home screen crafts and reloads authoritative inventory', (
    WidgetTester tester,
  ) async {
    int loads = 0;
    String? sentRecipeId;
    String? sentKey;

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          loader: () async {
            loads += 1;
            return loads == 1 ? _craftingReady() : _craftingCompleted();
          },
          idempotencyKeyFactory: () => 'craft-key',
          crafter:
              ({
                required String recipeId,
                required String idempotencyKey,
              }) async {
                sentRecipeId = recipeId;
                sentKey = idempotencyKey;
                return _craftingResult();
              },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder craftButton = find.byKey(
      const Key('craft-resonance-compass-v1'),
    );
    await tester.scrollUntilVisible(
      craftButton,
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(craftButton).onPressed, isNotNull);

    await tester.tap(craftButton);
    await tester.pumpAndSettle();

    expect(sentRecipeId, 'resonance-compass-v1');
    expect(sentKey, 'craft-key');
    expect(loads, 2);
    final Finder uniqueItem = find.text('Резонансный компас · уровень 1');
    await tester.scrollUntilVisible(
      uniqueItem,
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    expect(uniqueItem, findsOneWidget);

    final Finder craftedStatus = find.text('Предмет уже создан');
    await tester.scrollUntilVisible(
      craftedStatus,
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    expect(craftedStatus, findsOneWidget);
    expect(find.byKey(const Key('home-craftable-recipes')), findsNothing);
    expect(
      find.byKey(
        const Key(
          'crafting-assembly-signal-resonance-compass-v1-'
          'resonanceCompass-CRAFTED',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('cached home keeps crafting read-only', (
    WidgetTester tester,
  ) async {
    int craftCalls = 0;
    int impressionCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          loader: () async => _craftingReady(
            cacheMetadata: CachedReadMetadata(
              cachedAt: DateTime.utc(2026, 7, 27, 9),
              reason: 'Нет соединения с сервером',
            ),
          ),
          crafter:
              ({
                required String recipeId,
                required String idempotencyKey,
              }) async {
                craftCalls += 1;
                return _craftingResult();
              },
          impressionRecorder:
              ({
                required String commandType,
                required Map<String, Object?> payload,
                required String idempotencyKey,
              }) async {
                impressionCalls += 1;
                return null;
              },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder craftButton = find.byKey(
      const Key('craft-resonance-compass-v1'),
    );
    await tester.scrollUntilVisible(
      craftButton,
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(craftButton).onPressed, isNull);
    expect(find.text('Создание недоступно офлайн'), findsOneWidget);
    expect(craftCalls, 0);
    expect(impressionCalls, 0);
  });

  testWidgets('home attunes item and reloads authoritative epic rarity', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    int loads = 0;
    String? sentUpgradeId;
    String? sentKey;

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          loader: () async {
            loads += 1;
            return loads == 1 ? _upgradeReady() : _upgradeCompleted();
          },
          idempotencyKeyFactory: () => 'upgrade-key',
          itemUpgradeExecutor:
              ({
                required String upgradeId,
                required String idempotencyKey,
              }) async {
                sentUpgradeId = upgradeId;
                sentKey = idempotencyKey;
                return _itemUpgradeResult();
              },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-ready-item-upgrades')), findsOneWidget);
    expect(find.text('Можно применить 1 улучшение'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Можно применить 1 улучшение'),
      findsOneWidget,
    );

    final Finder upgradeButton = find.byKey(
      const Key('item-upgrade-prism-sextant-second-dawn-attunement-v1'),
    );
    await tester.scrollUntilVisible(
      upgradeButton,
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(upgradeButton).onPressed, isNotNull);

    await tester.tap(upgradeButton);
    await tester.pumpAndSettle();

    expect(sentUpgradeId, 'prism-sextant-second-dawn-attunement-v1');
    expect(sentKey, 'upgrade-key');
    expect(loads, 2);
    final Finder completed = find.text('Улучшение завершено');
    await tester.scrollUntilVisible(
      completed,
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    expect(completed, findsOneWidget);
    expect(
      find.text('Призматический секстант · уровень 3 · EPIC'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('home-ready-item-upgrades')), findsNothing);
    semantics.dispose();
  });

  testWidgets('ready item upgrade guidance reflows on compact enlarged text', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
        home: HomeScreen(loader: () async => _upgradeReady()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(
        const Key('item-upgrade-prism-sextant-second-dawn-attunement-v1'),
      ),
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-ready-item-upgrades')), findsOneWidget);
    expect(find.text('Можно применить 1 улучшение'), findsOneWidget);
  });

  testWidgets('equipment unlocks and unequip locks resonance route', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    int loads = 0;
    int keys = 0;
    final List<String> actions = <String>[];
    final List<String?> itemInstanceIds = <String?>[];
    final List<String> idempotencyKeys = <String>[];
    final List<String> impressions = <String>[];
    final List<String> impressionKeys = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          loader: () async {
            loads += 1;
            return _resonanceEventReady(equipped: loads == 2);
          },
          idempotencyKeyFactory: () => 'equipment-key-${++keys}',
          equipmentExecutor:
              ({
                required String slotId,
                required String action,
                required String? itemInstanceId,
                required String idempotencyKey,
              }) async {
                actions.add(action);
                itemInstanceIds.add(itemInstanceId);
                idempotencyKeys.add(idempotencyKey);
                return _equipmentResult(action: action);
              },
          impressionRecorder:
              ({
                required String commandType,
                required Map<String, Object?> payload,
                required String idempotencyKey,
              }) async {
                expect(commandType, 'RECORD_COMPASS_IMPRESSION');
                impressions.add(payload['impression']! as String);
                impressionKeys.add(idempotencyKey);
                return null;
              },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(impressions, isEmpty);
    expect(
      find.byKey(const Key('home-equippable-inventory-items')),
      findsOneWidget,
    );
    expect(find.text('Можно экипировать 1 предмет'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Можно экипировать 1 предмет'),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key('equipment-mount-signal-NAVIGATION-navigation-empty-EMPTY'),
      ),
      findsOneWidget,
    );

    final Finder routeChoice = find.byKey(
      const Key('home-event-choice-follow-resonance'),
    );
    await _scrollAboveStickyAction(tester, routeChoice);
    expect(tester.widget<FilledButton>(routeChoice).onPressed, isNull);
    expect(impressions, <String>['ROUTE_LOCKED']);
    expect(
      find.byKey(const Key('home-choice-locked-follow-resonance')),
      findsOneWidget,
    );

    final Finder equip = find.byKey(
      const Key('inventory-equip-resonance-compass'),
    );
    await tester.scrollUntilVisible(
      equip,
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    await tester.tap(equip);
    await tester.pumpAndSettle();

    expect(actions, <String>['EQUIP']);
    expect(itemInstanceIds, <String?>['33333333-3333-3333-3333-333333333333']);
    expect(idempotencyKeys, <String>['equipment-key-1']);
    expect(loads, 2);
    expect(
      find.byKey(const Key('home-equippable-inventory-items')),
      findsNothing,
    );
    expect(
      find.byKey(
        const Key(
          'equipment-mount-signal-NAVIGATION-navigation-'
          'resonanceCompass-EQUIPPED',
        ),
      ),
      findsOneWidget,
    );
    await _scrollAboveStickyAction(tester, routeChoice);
    expect(tester.widget<FilledButton>(routeChoice).onPressed, isNotNull);
    expect(impressions, <String>['ROUTE_LOCKED', 'ROUTE_AVAILABLE']);

    final Finder unequip = find.byKey(
      const Key('equipment-unequip-NAVIGATION'),
    );
    await tester.scrollUntilVisible(
      unequip,
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('equipment-card')),
        matching: find.byKey(const Key('item-art-resonance-compass')),
      ),
      findsOneWidget,
    );
    await tester.tap(unequip);
    await tester.pumpAndSettle();

    expect(actions, <String>['EQUIP', 'UNEQUIP']);
    expect(itemInstanceIds, <String?>[
      '33333333-3333-3333-3333-333333333333',
      null,
    ]);
    expect(idempotencyKeys, <String>['equipment-key-1', 'equipment-key-2']);
    expect(loads, 3);
    await _scrollAboveStickyAction(tester, routeChoice);
    expect(tester.widget<FilledButton>(routeChoice).onPressed, isNull);
    expect(impressions, <String>['ROUTE_LOCKED', 'ROUTE_AVAILABLE']);
    expect(impressionKeys, <String>[
      'compass-impression-chapter-1-v2-'
          'route-mirror-delta-v1-follow-resonance-ROUTE_LOCKED',
      'compass-impression-chapter-1-v2-'
          'route-mirror-delta-v1-follow-resonance-ROUTE_AVAILABLE',
    ]);
    expect(
      find.byKey(const Key('home-equippable-inventory-items')),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('equippable inventory guidance reflows on compact large text', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
        home: HomeScreen(
          loader: () async => _resonanceEventReady(equipped: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('inventory-equip-resonance-compass')),
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('home-equippable-inventory-items')),
      findsOneWidget,
    );
    expect(find.text('Можно экипировать 1 предмет'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('current READY event localizes on compact enlarged text', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final SemanticsHandle semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: WalkingRpgTheme.dark(),
        builder: (BuildContext context, Widget? child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          );
        },
        home: HomeScreen(
          loader: () async => _resonanceEventReady(equipped: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder eventScene = find.byKey(
      const Key('event-scene-mirror-delta-v1'),
    );
    await tester.scrollUntilVisible(
      eventScene,
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(
        'Event scene “Split Signal”: two reflected signals diverge above a '
        'hidden resonance current.',
      ),
      findsOneWidget,
    );

    final Finder lockedChoice = find.byKey(
      const Key('home-event-choice-follow-resonance'),
    );
    await _scrollAboveStickyAction(tester, lockedChoice);

    expect(find.text('Split Signal'), findsOneWidget);
    expect(
      find.text('Two identical signals lead to different shores.'),
      findsOneWidget,
    );
    expect(find.text('Survey the node'), findsOneWidget);
    expect(find.text('Follow the resonance'), findsOneWidget);
    expect(
      find.text("Tune the equipped compass to the delta's hidden reflection."),
      findsOneWidget,
    );
    expect(
      find.text('Equip the Resonance Compass to reveal the hidden route.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    semantics.dispose();
  });

  testWidgets('equipment mount stays reachable on compact enlarged text', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
        home: HomeScreen(
          loader: () async => _resonanceEventReady(equipped: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder unequip = find.byKey(
      const Key('equipment-unequip-NAVIGATION'),
    );
    await _scrollAboveStickyAction(tester, unequip);

    final Finder mount = find.byType(EquipmentMountSignal);
    expect(mount, findsOneWidget);
    expect(tester.getSize(mount).height, 112);
    expect(tester.getSize(mount).width, lessThanOrEqualTo(248));
    expect(unequip, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('adult pet choice shows the server evolution lock reason', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(loader: () async => _adultPetEventReady())),
    );
    await tester.pumpAndSettle();

    final Finder choice = find.byKey(
      const Key('home-event-choice-root-constellation-gate'),
    );
    await _scrollAboveStickyAction(tester, choice);

    expect(tester.widget<FilledButton>(choice).onPressed, isNull);
    expect(
      find.byKey(const Key('home-choice-locked-root-constellation-gate')),
      findsOneWidget,
    );
    expect(
      find.text(
        'Выберите взрослого Мха-оплота активным питомцем, чтобы вырастить живой проход.',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key(
          'event-choice-signal-uncharted-verge-v1-root-constellation-gate-'
          'stabilize-muted',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('signal reader choice shows the server skill lock reason', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(loader: () async => _signalReaderEventReady()),
      ),
    );
    await tester.pumpAndSettle();

    final Finder choice = find.byKey(
      const Key('home-event-choice-decode-sanctuary-signal'),
    );
    await _scrollAboveStickyAction(tester, choice);

    expect(tester.widget<FilledButton>(choice).onPressed, isNull);
    expect(
      find.byKey(const Key('home-choice-locked-decode-sanctuary-signal')),
      findsOneWidget,
    );
    expect(
      find.text(
        'Откройте навык «Чтение сигналов», чтобы расшифровать скрытый хор святилища.',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key(
          'event-choice-signal-constellation-sanctuary-v1-'
          'decode-sanctuary-signal-frequency-muted',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('secret observatory renders both terminal route signals', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(loader: () async => _hiddenSignalObservatoryReady()),
      ),
    );
    await tester.pumpAndSettle();

    for (final (String choiceId, String signalKind) in <(String, String)>[
      ('chart-hidden-sector', 'chart'),
      ('preserve-echo-key', 'companion'),
    ]) {
      final Finder choice = find.byKey(Key('home-event-choice-$choiceId'));
      await _scrollAboveStickyAction(tester, choice);
      expect(tester.widget<FilledButton>(choice).onPressed, isNotNull);
      expect(
        find.byKey(
          Key(
            'event-choice-signal-hidden-signal-observatory-v1-'
            '$choiceId-$signalKind-active',
          ),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('Trail Memory route shows the server skill lock reason', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(loader: () async => _trailMemoryRouteLocked()),
      ),
    );
    await tester.pumpAndSettle();

    final Finder choice = find.byKey(
      const Key('home-event-choice-reconstruct-forgotten-route'),
    );
    await _scrollAboveStickyAction(tester, choice);

    expect(tester.widget<FilledButton>(choice).onPressed, isNull);
    expect(
      find.byKey(const Key('home-choice-locked-reconstruct-forgotten-route')),
      findsOneWidget,
    );
    expect(
      find.text(
        'Откройте навык «Память маршрута», чтобы восстановить забытый путь обсерватории.',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key(
          'event-choice-signal-hidden-signal-observatory-v1-'
          'reconstruct-forgotten-route-echo-muted',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('memory constellation renders both terminal route signals', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(loader: () async => _memoryConstellationReady()),
      ),
    );
    await tester.pumpAndSettle();

    for (final (String choiceId, String signalKind) in <(String, String)>[
      ('archive-return-path', 'chart'),
      ('entrust-memory-to-pet', 'companion'),
    ]) {
      final Finder choice = find.byKey(Key('home-event-choice-$choiceId'));
      await _scrollAboveStickyAction(tester, choice);
      expect(tester.widget<FilledButton>(choice).onPressed, isNotNull);
      expect(
        find.byKey(
          Key(
            'event-choice-signal-memory-constellation-v1-'
            '$choiceId-$signalKind-active',
          ),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('Energy Discipline route shows the server skill lock reason', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(loader: () async => _energyDisciplineRouteLocked()),
      ),
    );
    await tester.pumpAndSettle();

    final Finder choice = find.byKey(
      const Key('home-event-choice-stabilize-dawn-current'),
    );
    await _scrollAboveStickyAction(tester, choice);

    expect(tester.widget<FilledButton>(choice).onPressed, isNull);
    expect(
      find.byKey(const Key('home-choice-locked-stabilize-dawn-current')),
      findsOneWidget,
    );
    expect(
      find.text(
        'Откройте навык «Дисциплина энергии», чтобы стабилизировать поток рассвета.',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key(
          'event-choice-signal-memory-constellation-v1-'
          'stabilize-dawn-current-stabilize-muted',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('dawn meridian renders both terminal route signals', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(loader: () async => _dawnMeridianReady())),
    );
    await tester.pumpAndSettle();

    for (final (String choiceId, String signalKind) in <(String, String)>[
      ('anchor-dawn-flow', 'chart'),
      ('share-dawn-flow-with-pet', 'companion'),
    ]) {
      final Finder choice = find.byKey(Key('home-event-choice-$choiceId'));
      await _scrollAboveStickyAction(tester, choice);
      expect(tester.widget<FilledButton>(choice).onPressed, isNotNull);
      expect(
        find.byKey(
          Key(
            'event-choice-signal-dawn-meridian-v1-'
            '$choiceId-$signalKind-active',
          ),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('Steady Step route shows the server skill lock reason', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(loader: () async => _steadyStepRouteLocked()),
      ),
    );
    await tester.pumpAndSettle();

    final Finder choice = find.byKey(
      const Key('home-event-choice-cross-first-light-causeway'),
    );
    await _scrollAboveStickyAction(tester, choice);

    expect(tester.widget<FilledButton>(choice).onPressed, isNull);
    expect(
      find.byKey(const Key('home-choice-locked-cross-first-light-causeway')),
      findsOneWidget,
    );
    expect(
      find.text('Откройте навык «Ровный шаг», чтобы перейти по первому свету.'),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key(
          'event-choice-signal-dawn-meridian-v1-'
          'cross-first-light-causeway-stabilize-muted',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('first-light causeway renders both terminal route signals', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(loader: () async => _firstLightCausewayReady()),
      ),
    );
    await tester.pumpAndSettle();

    for (final (String choiceId, String signalKind) in <(String, String)>[
      ('map-first-light-pulse', 'chart'),
      ('follow-pets-steady-pace', 'companion'),
    ]) {
      final Finder choice = find.byKey(Key('home-event-choice-$choiceId'));
      await _scrollAboveStickyAction(tester, choice);
      expect(tester.widget<FilledButton>(choice).onPressed, isNotNull);
      expect(
        find.byKey(
          Key(
            'event-choice-signal-first-light-causeway-v1-'
            '$choiceId-$signalKind-active',
          ),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets(
    'home screen keeps result visible until acknowledgement and reloads',
    (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      int loads = 0;
      String? sentEventId;
      String? sentChoiceId;
      String? sentKey;
      String? acknowledgedReceiptId;
      String? acknowledgementKey;

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            loader: () async {
              loads += 1;
              return switch (loads) {
                1 => _secondEventReady(),
                2 => _pendingEventResultHome(),
                _ => _acknowledgedEventResultHome(),
              };
            },
            idempotencyKeyFactory: () => 'event-key',
            eventResolver:
                ({
                  required String eventId,
                  required String choiceId,
                  required String idempotencyKey,
                }) async {
                  sentEventId = eventId;
                  sentChoiceId = choiceId;
                  sentKey = idempotencyKey;
                  return _eventResolutionResult();
                },
            eventResultAcknowledger:
                ({
                  required String receiptId,
                  required String idempotencyKey,
                }) async {
                  acknowledgedReceiptId = receiptId;
                  acknowledgementKey = idempotencyKey;
                  return EventResultAcknowledgement(
                    receiptId: receiptId,
                    eventId: 'echo-vault-v1',
                    status: 'ACKNOWLEDGED',
                    acknowledgedAt: '2026-07-26T06:01:00Z',
                    serverTime: '2026-07-26T06:01:00Z',
                  );
                },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Finder choiceButton = find.widgetWithText(
        FilledButton,
        'Стабилизировать ядро',
      );
      await tester.scrollUntilVisible(
        choiceButton,
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: choiceButton,
          matching: find.byKey(const Key('item-art-lumen-shard')),
        ),
        findsOneWidget,
      );
      await tester.tap(choiceButton);
      await tester.pumpAndSettle();

      expect(sentEventId, 'echo-vault-v1');
      expect(sentChoiceId, 'stabilize-core');
      expect(sentKey, 'event-key');
      expect(loads, 2);

      final Finder pendingResult = find.byKey(
        const Key('pending-event-result-card'),
      );
      expect(pendingResult, findsOneWidget);
      expect(
        find.descendant(
          of: pendingResult,
          matching: find.byKey(const Key('event-scene-echo-vault-v1')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: pendingResult,
          matching: find.byKey(
            const Key(
              'progression-gain-signal-pilotExperience-navigator-v1-'
              'navigator',
            ),
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: pendingResult,
          matching: find.byKey(
            const Key('progression-gain-signal-petBond-spark-v1-spark'),
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: pendingResult,
          matching: find.byKey(
            const Key(
              'event-choice-signal-echo-vault-v1-stabilize-core-'
              'stabilize-active',
            ),
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: pendingResult,
          matching: find.byKey(const Key('item-art-lumen-shard')),
        ),
        findsOneWidget,
      );
      expect(find.text('Стабильный резонанс'), findsOneWidget);
      expect(find.text('СЛЕДУЮЩИЙ УЗЕЛ'), findsOneWidget);
      expect(
        find.descendant(
          of: pendingResult,
          matching: find.byKey(
            const Key('expedition-next-node-signal-ash-orbit-ashOrbit'),
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Следующий узел «Пепельная орбита»'),
        findsOneWidget,
      );

      final Finder acknowledgementButton = find.byKey(
        const Key('pending-event-result-acknowledge'),
      );
      await tester.scrollUntilVisible(
        acknowledgementButton,
        200,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();
      await tester.tap(acknowledgementButton);
      await tester.pumpAndSettle();

      expect(acknowledgedReceiptId, '22222222-2222-2222-2222-222222222222');
      expect(acknowledgementKey, 'event-key');
      expect(loads, 3);
      expect(pendingResult, findsNothing);
      expect(
        find.textContaining('0 / 55 энергии · Пепельная орбита'),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(
        find.text('XP 90 / 100 · до следующего уровня 10 XP'),
        200,
        scrollable: find.byType(Scrollable),
      );
      expect(
        find.text('XP 90 / 100 · до следующего уровня 10 XP'),
        findsOneWidget,
      );
      expect(find.text('Связь 23'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Люминовый осколок × 2'),
        200,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('Люминовый осколок × 2'), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets('completed expedition begins an idempotent next journey', (
    WidgetTester tester,
  ) async {
    int loads = 0;
    String? sentExpeditionId;
    int? sentExpectedJourneyNumber;
    String? sentKey;

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          loader: () async {
            loads += 1;
            return loads == 1 ? _completedJourney() : _startedThirdJourney();
          },
          idempotencyKeyFactory: () => 'journey-key',
          expeditionJourneyStarter:
              ({
                required String expeditionId,
                required int expectedJourneyNumber,
                required String idempotencyKey,
              }) async {
                sentExpeditionId = expeditionId;
                sentExpectedJourneyNumber = expectedJourneyNumber;
                sentKey = idempotencyKey;
                return _journeyResult();
              },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ПОХОД №2'), findsOneWidget);
    final Finder begin = find.byKey(const Key('home-begin-next-journey'));
    expect(begin, findsOneWidget);
    expect(find.text('Начать поход №3'), findsOneWidget);

    await tester.tap(begin);
    await tester.pumpAndSettle();

    expect(sentExpeditionId, 'starter-expedition-v1');
    expect(sentExpectedJourneyNumber, 2);
    expect(sentKey, 'journey-key');
    expect(loads, 2);
    expect(find.text('Начат поход №3'), findsOneWidget);
    expect(find.text('ПОХОД №3'), findsOneWidget);
    expect(find.byKey(const Key('home-advance-expedition')), findsOneWidget);
  });

  testWidgets('cached completed expedition cannot begin another journey', (
    WidgetTester tester,
  ) async {
    int calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          loader: () async => _completedJourney(
            cacheMetadata: CachedReadMetadata(
              cachedAt: DateTime.utc(2026, 8, 17, 6),
              reason: 'Нет соединения с сервером',
            ),
          ),
          expeditionJourneyStarter:
              ({
                required String expeditionId,
                required int expectedJourneyNumber,
                required String idempotencyKey,
              }) async {
                calls += 1;
                return _journeyResult();
              },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final FilledButton button = tester.widget<FilledButton>(
      find.byKey(const Key('home-begin-next-journey')),
    );
    expect(button.onPressed, isNull);
    expect(find.text('Изменения недоступны офлайн'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets(
    'pending result keeps future progression subjects fully neutral',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: WalkingRpgTheme.dark(),
          home: HomeScreen(
            loader: () async => _pendingEventResultHome(
              resultPilotId: 'future-pilot-v2',
              resultPetId: 'future-pet-v2',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const Key(
            'progression-gain-signal-pilotExperience-future-pilot-v2-unknown',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key('progression-gain-signal-petBond-future-pet-v2-unknown'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key(
            'progression-gain-signal-pilotExperience-future-pilot-v2-'
            'navigator',
          ),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          const Key('progression-gain-signal-petBond-future-pet-v2-spark'),
        ),
        findsNothing,
      );
      expect(find.text('+30 XP · всего 90'), findsOneWidget);
      expect(find.text('+8 связи · Искра: 23'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pending result disables an overlapping ready event', (
    WidgetTester tester,
  ) async {
    int resolutions = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          loader: () async => _pendingEventResultHome(includeReadyEvent: true),
          eventResolver:
              ({
                required String eventId,
                required String choiceId,
                required String idempotencyKey,
              }) async {
                resolutions += 1;
                return _eventResolutionResult();
              },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder choiceButton = find.widgetWithText(
      FilledButton,
      'Стабилизировать ядро',
    );
    await tester.scrollUntilVisible(
      choiceButton,
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    expect(choiceButton, findsOneWidget);
    expect(tester.widget<FilledButton>(choiceButton).onPressed, isNull);
    expect(resolutions, 0);
  });

  testWidgets(
    'resolved event keeps exact choice identity and future pairs neutral',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      Future<void> pump(HomeExpeditionEvent event) async {
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: WalkingRpgTheme.dark(),
            home: HomeScreen(
              key: ValueKey<String>(event.eventId),
              loader: () async => _pendingEventResultHome(
                includePending: false,
                unlockedEvent: event,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pump(
        const HomeExpeditionEvent(
          eventId: 'echo-vault-v1',
          title: 'Хранилище эха',
          summary: 'Архивное ядро стабилизировано.',
          status: 'RESOLVED',
          selectedChoiceId: 'stabilize-core',
          selectedChoiceTitle: 'Стабилизировать ядро',
          outcomeTitle: 'Стабильный резонанс',
          outcomeSummary: 'Ядро перестало разрушаться.',
        ),
      );
      final Finder known = find.byKey(
        const Key(
          'event-choice-signal-echo-vault-v1-stabilize-core-'
          'stabilize-active',
        ),
      );
      await tester.scrollUntilVisible(
        known,
        220,
        scrollable: find.byType(Scrollable),
      );
      expect(known, findsOneWidget);
      expect(find.text('Хранилище эха'), findsOneWidget);
      expect(find.text('Архивное ядро стабилизировано.'), findsOneWidget);
      expect(find.text('Стабилизировать ядро'), findsOneWidget);
      expect(find.text('Стабильный резонанс'), findsOneWidget);
      expect(find.text('Ядро перестало разрушаться.'), findsOneWidget);
      expect(find.text('Echo Vault'), findsNothing);

      await pump(
        const HomeExpeditionEvent(
          eventId: 'future-event-v2',
          title: 'Новый сигнал',
          summary: 'Сервер прислал новый тип события.',
          status: 'RESOLVED',
          selectedChoiceId: 'stabilize-core',
          selectedChoiceTitle: 'Стабилизировать новый контур',
          outcomeTitle: 'Новый результат',
          outcomeSummary: 'Полный результат остаётся серверным текстом.',
        ),
      );
      final Finder fallback = find.byKey(
        const Key(
          'event-choice-signal-future-event-v2-stabilize-core-unknown-active',
        ),
      );
      await tester.scrollUntilVisible(
        fallback,
        220,
        scrollable: find.byType(Scrollable),
      );
      expect(fallback, findsOneWidget);
      expect(find.text('Стабилизировать новый контур'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('home screen can retry after backend error', (
    WidgetTester tester,
  ) async {
    int attempts = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          loader: () async {
            attempts += 1;
            if (attempts == 1) {
              throw const HomeApiException(
                statusCode: 503,
                message: 'Backend недоступен',
              );
            }
            return HomeSnapshot.demo;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Не удалось загрузить состояние'), findsOneWidget);
    expect(find.byKey(const Key('home-error-state')), findsOneWidget);
    expect(find.byType(ExpeditionReadState), findsOneWidget);
    expect(
      find.text(
        'Актуальный маршрут не принят. Повтори запрос или открой локальное '
        'демонстрационное состояние — оно не меняет серверные данные.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Backend недоступен'), findsNothing);
    await tester.tap(find.byKey(const Key('home-error-retry')));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('Сегодня: 0 / 6000'), findsOneWidget);
  });

  testWidgets(
    'cached home is clearly read-only while refresh stays available',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            loader: () async => _readyToAdvance(
              cacheMetadata: CachedReadMetadata(
                cachedAt: DateTime.utc(2026, 7, 27, 9),
                reason: 'Нет соединения с сервером',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cached-snapshot-banner')), findsOneWidget);
      expect(
        find.textContaining('Изменения временно недоступны'),
        findsOneWidget,
      );

      final Finder advanceFinder = find.widgetWithText(
        FilledButton,
        'Изменения недоступны офлайн',
      );
      await tester.scrollUntilVisible(
        advanceFinder,
        200,
        scrollable: find.byType(Scrollable),
      );
      final FilledButton advance = tester.widget<FilledButton>(advanceFinder);
      expect(advance.onPressed, isNull);

      final Finder refreshFinder = find.widgetWithText(
        OutlinedButton,
        'Обновить состояние',
      );
      await tester.scrollUntilVisible(
        refreshFinder,
        200,
        scrollable: find.byType(Scrollable),
      );
      final OutlinedButton refresh = tester.widget<OutlinedButton>(
        refreshFinder,
      );
      expect(refresh.onPressed, isNotNull);
    },
  );

  testWidgets(
    'cached pending result stays visible but cannot be acknowledged',
    (WidgetTester tester) async {
      int acknowledgementCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            loader: () async => _pendingEventResultHome(
              cacheMetadata: CachedReadMetadata(
                cachedAt: DateTime.utc(2026, 7, 27, 9),
                reason: 'Нет соединения с сервером',
              ),
            ),
            eventResultAcknowledger:
                ({
                  required String receiptId,
                  required String idempotencyKey,
                }) async {
                  acknowledgementCalls += 1;
                  throw StateError('cached snapshot must be read-only');
                },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('pending-event-result-card')),
        findsOneWidget,
      );
      final Finder acknowledgementFinder = find.byKey(
        const Key('pending-event-result-acknowledge'),
      );
      await tester.scrollUntilVisible(
        acknowledgementFinder,
        200,
        scrollable: find.byType(Scrollable),
      );
      final FilledButton acknowledgement = tester.widget<FilledButton>(
        acknowledgementFinder,
      );
      expect(acknowledgement.onPressed, isNull);
      expect(find.text('Подтверждение недоступно офлайн'), findsOneWidget);
      expect(acknowledgementCalls, 0);
    },
  );
}

HomeSnapshot _routeWithDecision() {
  return const HomeSnapshot(
    localDate: '2026-07-26',
    timeZone: 'Europe/Berlin',
    dailySteps: 6842,
    dailyGoal: 6000,
    availableEnergy: 38,
    activityStateVersion: 1,
    economyVersion: 2,
    lastActivitySyncAt: '2026-07-26T05:55:00Z',
    serverTime: '2026-07-26T06:00:00Z',
    contentVersion: 'chapter-1-v1',
    expeditionId: 'starter-expedition-v1',
    expeditionName: 'Сигнал из туманного сектора',
    currentNodeId: 'lumen-gate',
    currentNodeName: 'Люминовые ворота',
    expeditionProgress: 30,
    requiredEnergy: 45,
    expeditionStatus: 'IN_PROGRESS',
    expeditionVersion: 2,
    unlockedEvent: null,
    pilotName: 'Навигатор',
    pilotLevel: 1,
    petId: 'spark-v1',
    petName: 'Искра',
    petSpecies: 'Люмин',
    petLevel: 1,
    routeTrail: <HomeExpeditionRouteNode>[
      HomeExpeditionRouteNode(
        nodeId: 'outer-beacon',
        nodeName: 'Внешний маяк',
        state: 'VISITED',
        decision: HomeExpeditionRouteDecision(
          choiceId: 'follow-pulse',
          choiceTitle: 'Пойти за импульсом',
          outcomeTitle: 'Найден маяк',
        ),
      ),
      HomeExpeditionRouteNode(
        nodeId: 'lumen-gate',
        nodeName: 'Люминовые ворота',
        state: 'CURRENT',
      ),
    ],
  );
}

Future<void> _scrollAboveStickyAction(
  WidgetTester tester,
  Finder target,
) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find.byType(Scrollable),
  );
  await tester.pumpAndSettle();

  final Finder stickyAction = find.byKey(const Key('home-sticky-action-panel'));
  final double targetTop = tester.getTopLeft(target).dy;
  final double stickyTop = tester.getTopLeft(stickyAction).dy;
  const double visibleExtent = 24;
  if (targetTop < stickyTop - visibleExtent) {
    return;
  }

  final ScrollPosition position = tester
      .state<ScrollableState>(find.byType(Scrollable))
      .position;
  position.jumpTo(
    (position.pixels + targetTop - stickyTop + visibleExtent)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble(),
  );
  await tester.pumpAndSettle();
}

const DailyGoalPolicy _adaptiveGoalPolicy = DailyGoalPolicy(
  policyVersion: 'adaptive-median-v1',
  source: 'ADAPTIVE',
  baselineSteps: 3000,
  sampleDays: 3,
  lookbackDays: 7,
  minimumSampleDays: 3,
  defaultGoal: 6000,
  growthPercent: 5,
  roundingStep: 250,
  minimumGoal: 2000,
  maximumGoal: 12000,
);

HomeSnapshot _futureNode() {
  return const HomeSnapshot(
    localDate: '2026-07-26',
    timeZone: 'Europe/Berlin',
    dailySteps: 3200,
    dailyGoal: 6000,
    availableEnergy: 16,
    activityStateVersion: 2,
    economyVersion: 2,
    lastActivitySyncAt: '2026-07-26T05:55:00Z',
    serverTime: '2026-07-26T06:00:00Z',
    contentVersion: 'chapter-1-v2',
    expeditionId: 'starter-expedition-v1',
    expeditionName: 'Сигнал из туманного сектора',
    currentNodeId: 'future-node-v2',
    currentNodeName: 'Внешний маяк',
    expeditionProgress: 10,
    requiredEnergy: 40,
    expeditionStatus: 'IN_PROGRESS',
    expeditionVersion: 22,
    unlockedEvent: null,
    pilotName: 'Навигатор',
    pilotLevel: 2,
    petName: 'Искра',
    petLevel: 2,
  );
}

HomeSnapshot _readyToAdvance({
  CachedReadMetadata? cacheMetadata,
  WeeklyActivityRhythm? weeklyActivityRhythm,
  int dailySteps = 6842,
  int dailyGoal = 3250,
}) {
  return HomeSnapshot(
    localDate: '2026-07-26',
    timeZone: 'Europe/Berlin',
    dailySteps: dailySteps,
    dailyGoal: dailyGoal,
    dailyGoalPolicy: _adaptiveGoalPolicy,
    weeklyActivityRhythm:
        weeklyActivityRhythm ??
        const WeeklyActivityRhythm(
          activeDays: 5,
          windowDays: 7,
          targetActiveDays: 4,
          targetReached: true,
          days: <WeeklyActivityDay>[
            WeeklyActivityDay(localDate: '2026-07-20', active: true),
            WeeklyActivityDay(localDate: '2026-07-21', active: true),
            WeeklyActivityDay(localDate: '2026-07-22', active: false),
            WeeklyActivityDay(localDate: '2026-07-23', active: true),
            WeeklyActivityDay(localDate: '2026-07-24', active: false),
            WeeklyActivityDay(localDate: '2026-07-25', active: true),
            WeeklyActivityDay(localDate: '2026-07-26', active: true),
          ],
        ),
    availableEnergy: 68,
    activityStateVersion: 1,
    economyVersion: 1,
    lastActivitySyncAt: '2026-07-26T05:55:00Z',
    serverTime: '2026-07-26T06:00:00Z',
    contentVersion: 'chapter-1-v1',
    expeditionId: 'starter-expedition-v1',
    expeditionName: 'Сигнал из туманного сектора',
    currentNodeId: 'outer-beacon',
    currentNodeName: 'Внешний маяк',
    expeditionProgress: 0,
    requiredEnergy: 30,
    expeditionStatus: 'IN_PROGRESS',
    expeditionVersion: 0,
    unlockedEvent: null,
    pilotName: 'Навигатор',
    pilotLevel: 1,
    pilotCurrentExperience: 20,
    pilotNextLevelExperience: 100,
    petName: 'Искра',
    petLevel: 1,
    petBond: 10,
    cacheMetadata: cacheMetadata,
  );
}

WeeklyActivityRhythm _weeklyRhythmWithActiveDays(
  int activeDays, {
  bool todayActive = false,
}) {
  const List<String> dates = <String>[
    '2026-07-20',
    '2026-07-21',
    '2026-07-22',
    '2026-07-23',
    '2026-07-24',
    '2026-07-25',
    '2026-07-26',
  ];
  return WeeklyActivityRhythm(
    activeDays: activeDays,
    windowDays: dates.length,
    targetActiveDays: 4,
    targetReached: activeDays >= 4,
    days: List<WeeklyActivityDay>.generate(dates.length, (int index) {
      final bool isToday = index == dates.length - 1;
      final int earlierActiveDays = activeDays - (todayActive ? 1 : 0);
      final bool isActive = isToday ? todayActive : index < earlierActiveDays;
      return WeeklyActivityDay(localDate: dates[index], active: isActive);
    }, growable: false),
  );
}

HomeSnapshot _completedJourney({CachedReadMetadata? cacheMetadata}) {
  return HomeSnapshot(
    localDate: '2026-08-17',
    timeZone: 'Europe/Berlin',
    dailySteps: 12000,
    dailyGoal: 6000,
    availableEnergy: 84,
    activityStateVersion: 9,
    economyVersion: 12,
    lastActivitySyncAt: '2026-08-17T05:55:00Z',
    serverTime: '2026-08-17T06:00:00Z',
    contentVersion: 'chapter-1-v15',
    expeditionId: 'starter-expedition-v1',
    expeditionName: 'Сигнал из туманного сектора',
    currentNodeId: 'first-light-causeway',
    currentNodeName: 'Переход первого света',
    expeditionProgress: 105,
    requiredEnergy: 105,
    expeditionStatus: 'COMPLETED',
    expeditionVersion: 60,
    expeditionJourneyNumber: 2,
    unlockedEvent: null,
    pilotName: 'Навигатор',
    pilotLevel: 7,
    pilotCurrentExperience: 888,
    pilotNextLevelExperience: 1400,
    petName: 'Искра',
    petLevel: 6,
    petBond: 777,
    cacheMetadata: cacheMetadata,
  );
}

HomeSnapshot _startedThirdJourney() {
  final HomeSnapshot completed = _completedJourney();
  return HomeSnapshot(
    localDate: completed.localDate,
    timeZone: completed.timeZone,
    dailySteps: completed.dailySteps,
    dailyGoal: completed.dailyGoal,
    availableEnergy: completed.availableEnergy,
    activityStateVersion: completed.activityStateVersion,
    economyVersion: completed.economyVersion,
    lastActivitySyncAt: completed.lastActivitySyncAt,
    serverTime: completed.serverTime,
    contentVersion: completed.contentVersion,
    expeditionId: completed.expeditionId,
    expeditionName: completed.expeditionName,
    currentNodeId: 'outer-beacon',
    currentNodeName: 'Внешний маяк',
    expeditionProgress: 0,
    requiredEnergy: 30,
    expeditionStatus: 'IN_PROGRESS',
    expeditionVersion: 61,
    expeditionJourneyNumber: 3,
    unlockedEvent: null,
    pilotName: completed.pilotName,
    pilotLevel: completed.pilotLevel,
    pilotCurrentExperience: completed.pilotCurrentExperience,
    pilotNextLevelExperience: completed.pilotNextLevelExperience,
    petName: completed.petName,
    petLevel: completed.petLevel,
    petBond: completed.petBond,
  );
}

ExpeditionJourneyResult _journeyResult() {
  return const ExpeditionJourneyResult(
    contentVersion: 'chapter-1-v15',
    expeditionId: 'starter-expedition-v1',
    expeditionName: 'Сигнал из туманного сектора',
    journeyNumber: 3,
    progressAfter: 0,
    requiredEnergy: 30,
    expeditionVersion: 61,
    status: 'IN_PROGRESS',
    currentNodeId: 'outer-beacon',
    currentNodeName: 'Внешний маяк',
    serverTime: '2026-08-17T06:00:00Z',
  );
}

HomeSnapshot _craftingReady({
  CachedReadMetadata? cacheMetadata,
  List<HomeInventoryItem>? inventory,
  List<HomeItemUpgrade> itemUpgrades = const <HomeItemUpgrade>[],
}) {
  return HomeSnapshot(
    localDate: '2026-07-26',
    timeZone: 'Europe/Berlin',
    dailySteps: 10000,
    dailyGoal: 3250,
    dailyGoalPolicy: _adaptiveGoalPolicy,
    availableEnergy: 0,
    activityStateVersion: 1,
    economyVersion: 3,
    lastActivitySyncAt: '2026-07-26T05:55:00Z',
    serverTime: '2026-07-26T06:00:00Z',
    contentVersion: 'chapter-1-v1',
    expeditionId: 'starter-expedition-v1',
    expeditionName: 'Сигнал из туманного сектора',
    currentNodeId: 'ash-orbit',
    currentNodeName: 'Пепельная орбита',
    expeditionProgress: 0,
    requiredEnergy: 55,
    expeditionStatus: 'IN_PROGRESS',
    expeditionVersion: 4,
    unlockedEvent: null,
    pilotName: 'Навигатор',
    pilotLevel: 1,
    pilotCurrentExperience: 90,
    pilotNextLevelExperience: 100,
    petName: 'Искра',
    petLevel: 1,
    petBond: 23,
    inventory:
        inventory ??
        const <HomeInventoryItem>[
          HomeInventoryItem(
            itemId: 'lumen-shard',
            name: 'Люминовый осколок',
            description: 'Стабильный фрагмент светового ядра.',
            quantity: 2,
            version: 1,
          ),
          HomeInventoryItem(
            itemId: 'echo-thread',
            name: 'Нить эха',
            description: 'Тонкая нить сохранённого сигнала.',
            quantity: 1,
            version: 1,
          ),
        ],
    craftingRecipes: const <HomeCraftingRecipe>[_readyRecipe],
    itemUpgrades: itemUpgrades,
    cacheMetadata: cacheMetadata,
  );
}

HomeSnapshot _upgradeReady() {
  return _craftingReady(
    inventory: const <HomeInventoryItem>[
      HomeInventoryItem(
        itemId: 'prism-sextant',
        name: 'Призматический секстант',
        description: 'Уникальный навигационный прибор.',
        quantity: 1,
        version: 2,
        kind: 'UNIQUE',
        itemInstanceId: '44444444-4444-4444-4444-444444444444',
        rarity: 'RARE',
      ),
      HomeInventoryItem(
        itemId: 'echo-thread',
        name: 'Нить эха',
        description: 'Тонкая нить сохранённого сигнала.',
        quantity: 2,
        version: 1,
      ),
      HomeInventoryItem(
        itemId: 'ion-bloom',
        name: 'Ионный цветок',
        description: 'Заряженный цветок.',
        quantity: 2,
        version: 1,
      ),
      HomeInventoryItem(
        itemId: 'dawn-fragment',
        name: 'Фрагмент рассвета',
        description: 'Осколок нового горизонта.',
        quantity: 2,
        version: 1,
      ),
    ],
    itemUpgrades: const <HomeItemUpgrade>[_readyItemUpgrade],
  );
}

HomeSnapshot _upgradeCompleted() {
  return _craftingReady(
    inventory: const <HomeInventoryItem>[
      HomeInventoryItem(
        itemId: 'prism-sextant',
        name: 'Призматический секстант',
        description: 'Уникальный навигационный прибор.',
        quantity: 1,
        version: 3,
        kind: 'UNIQUE',
        itemInstanceId: '44444444-4444-4444-4444-444444444444',
        rarity: 'EPIC',
      ),
    ],
    itemUpgrades: const <HomeItemUpgrade>[
      HomeItemUpgrade(
        upgradeId: 'prism-sextant-second-dawn-attunement-v1',
        upgradeVersion: '1',
        name: 'Настроить секстант на второй рассвет',
        description: 'Закрепить координаты нового горизонта.',
        status: 'COMPLETED',
        targetItemId: 'prism-sextant',
        targetItemName: 'Призматический секстант',
        requiredLevel: 2,
        resultingLevel: 3,
        initialRarity: 'RARE',
        resultingRarity: 'EPIC',
        ingredients: <HomeItemUpgradeIngredient>[
          HomeItemUpgradeIngredient(
            itemId: 'echo-thread',
            name: 'Нить эха',
            requiredQuantity: 2,
            availableQuantity: 0,
          ),
          HomeItemUpgradeIngredient(
            itemId: 'ion-bloom',
            name: 'Ионный цветок',
            requiredQuantity: 2,
            availableQuantity: 0,
          ),
          HomeItemUpgradeIngredient(
            itemId: 'dawn-fragment',
            name: 'Фрагмент рассвета',
            requiredQuantity: 2,
            availableQuantity: 0,
          ),
        ],
      ),
    ],
  );
}

const HomeItemUpgrade _readyItemUpgrade = HomeItemUpgrade(
  upgradeId: 'prism-sextant-second-dawn-attunement-v1',
  upgradeVersion: '1',
  name: 'Настроить секстант на второй рассвет',
  description: 'Закрепить координаты нового горизонта.',
  status: 'READY',
  targetItemId: 'prism-sextant',
  targetItemName: 'Призматический секстант',
  requiredLevel: 2,
  resultingLevel: 3,
  initialRarity: 'RARE',
  resultingRarity: 'EPIC',
  ingredients: <HomeItemUpgradeIngredient>[
    HomeItemUpgradeIngredient(
      itemId: 'echo-thread',
      name: 'Нить эха',
      requiredQuantity: 2,
      availableQuantity: 2,
    ),
    HomeItemUpgradeIngredient(
      itemId: 'ion-bloom',
      name: 'Ионный цветок',
      requiredQuantity: 2,
      availableQuantity: 2,
    ),
    HomeItemUpgradeIngredient(
      itemId: 'dawn-fragment',
      name: 'Фрагмент рассвета',
      requiredQuantity: 2,
      availableQuantity: 2,
    ),
  ],
);

HomeSnapshot _craftingCompleted() {
  final HomeSnapshot ready = _craftingReady();
  return HomeSnapshot(
    localDate: ready.localDate,
    timeZone: ready.timeZone,
    dailySteps: ready.dailySteps,
    dailyGoal: ready.dailyGoal,
    dailyGoalPolicy: ready.dailyGoalPolicy,
    availableEnergy: ready.availableEnergy,
    activityStateVersion: ready.activityStateVersion,
    economyVersion: ready.economyVersion,
    lastActivitySyncAt: ready.lastActivitySyncAt,
    serverTime: ready.serverTime,
    contentVersion: ready.contentVersion,
    expeditionId: ready.expeditionId,
    expeditionName: ready.expeditionName,
    currentNodeId: ready.currentNodeId,
    currentNodeName: ready.currentNodeName,
    expeditionProgress: ready.expeditionProgress,
    requiredEnergy: ready.requiredEnergy,
    expeditionStatus: ready.expeditionStatus,
    expeditionVersion: ready.expeditionVersion,
    unlockedEvent: ready.unlockedEvent,
    pilotName: ready.pilotName,
    pilotLevel: ready.pilotLevel,
    pilotCurrentExperience: ready.pilotCurrentExperience,
    pilotNextLevelExperience: ready.pilotNextLevelExperience,
    petName: ready.petName,
    petLevel: ready.petLevel,
    petBond: ready.petBond,
    inventory: const <HomeInventoryItem>[
      HomeInventoryItem(
        itemId: 'resonance-compass',
        name: 'Резонансный компас',
        description: 'Уникальный прибор.',
        quantity: 1,
        version: 1,
        kind: 'UNIQUE',
      ),
    ],
    craftingRecipes: const <HomeCraftingRecipe>[
      HomeCraftingRecipe(
        recipeId: 'resonance-compass-v1',
        recipeVersion: '1',
        name: 'Резонансный компас',
        description: 'Собрать прибор из трофеев экспедиции.',
        status: 'CRAFTED',
        ingredients: <HomeCraftingIngredient>[
          HomeCraftingIngredient(
            itemId: 'lumen-shard',
            name: 'Люминовый осколок',
            requiredQuantity: 2,
            availableQuantity: 0,
          ),
          HomeCraftingIngredient(
            itemId: 'echo-thread',
            name: 'Нить эха',
            requiredQuantity: 1,
            availableQuantity: 0,
          ),
        ],
        result: HomeCraftingResultPreview(
          itemId: 'resonance-compass',
          name: 'Резонансный компас',
          description: 'Уникальный прибор.',
          kind: 'UNIQUE',
        ),
      ),
    ],
  );
}

HomeSnapshot _resonanceEventReady({required bool equipped}) {
  const String itemInstanceId = '33333333-3333-3333-3333-333333333333';
  return HomeSnapshot(
    localDate: '2026-07-26',
    timeZone: 'Europe/Berlin',
    dailySteps: 12000,
    dailyGoal: 3250,
    dailyGoalPolicy: _adaptiveGoalPolicy,
    availableEnergy: 0,
    activityStateVersion: 1,
    economyVersion: 8,
    lastActivitySyncAt: '2026-07-26T05:55:00Z',
    serverTime: '2026-07-26T06:00:00Z',
    contentVersion: 'chapter-1-v2',
    expeditionId: 'starter-expedition-v1',
    expeditionName: 'Сигнал из туманного сектора',
    currentNodeId: 'mirror-delta',
    currentNodeName: 'Зеркальная дельта',
    expeditionProgress: 95,
    requiredEnergy: 95,
    expeditionStatus: 'EVENT_READY',
    expeditionVersion: 20,
    unlockedEvent: HomeExpeditionEvent(
      eventId: 'mirror-delta-v1',
      title: 'Раздвоенный сигнал',
      summary: 'Два сигнала ведут к разным берегам.',
      status: 'READY',
      choices: <HomeEventChoice>[
        const HomeEventChoice(
          choiceId: 'survey-mirror-delta',
          title: 'Исследовать узел',
          description: 'Сохранить обычный маршрут.',
          pilotExperienceReward: 31,
          petBondReward: 6,
        ),
        HomeEventChoice(
          choiceId: 'follow-resonance',
          title: 'Пойти по резонансу',
          description: 'Настроить компас на скрытое отражение.',
          pilotExperienceReward: 35,
          petBondReward: 16,
          availability: equipped ? 'AVAILABLE' : 'LOCKED',
          requirement: const HomeChoiceRequirement(
            type: 'EQUIPPED_ITEM',
            slotId: 'NAVIGATION',
            slotName: 'Навигационный прибор',
            itemId: 'resonance-compass',
            itemName: 'Резонансный компас',
            description:
                'Экипируйте резонансный компас, чтобы увидеть скрытый маршрут.',
          ),
        ),
      ],
    ),
    pilotName: 'Навигатор',
    pilotLevel: 2,
    pilotCurrentExperience: 40,
    pilotNextLevelExperience: 160,
    petName: 'Искра',
    petLevel: 2,
    petBond: 40,
    inventory: <HomeInventoryItem>[
      HomeInventoryItem(
        itemInstanceId: itemInstanceId,
        itemId: 'resonance-compass',
        name: 'Резонансный компас',
        description: 'Уникальный навигационный прибор.',
        quantity: 1,
        version: 1,
        kind: 'UNIQUE',
        equippableSlotId: 'NAVIGATION',
        equippedSlotId: equipped ? 'NAVIGATION' : null,
      ),
    ],
    equipment: <HomeEquipmentSlot>[
      HomeEquipmentSlot(
        slotId: 'NAVIGATION',
        name: 'Навигационный прибор',
        description: 'Инструмент, влияющий на доступные маршруты.',
        status: equipped ? 'EQUIPPED' : 'EMPTY',
        version: equipped ? 1 : 2,
        item: equipped
            ? const HomeEquipmentItem(
                itemInstanceId: itemInstanceId,
                itemId: 'resonance-compass',
                name: 'Резонансный компас',
                description: 'Уникальный навигационный прибор.',
              )
            : null,
      ),
    ],
  );
}

HomeSnapshot _adultPetEventReady() {
  return const HomeSnapshot(
    localDate: '2026-07-26',
    timeZone: 'Europe/Berlin',
    dailySteps: 12000,
    dailyGoal: 3250,
    dailyGoalPolicy: _adaptiveGoalPolicy,
    availableEnergy: 0,
    activityStateVersion: 1,
    economyVersion: 8,
    lastActivitySyncAt: '2026-07-26T05:55:00Z',
    serverTime: '2026-07-26T06:00:00Z',
    contentVersion: 'chapter-1-v12',
    expeditionId: 'starter-expedition-v1',
    expeditionName: 'Сигнал из туманного сектора',
    currentNodeId: 'uncharted-verge',
    currentNodeName: 'Неизведанный рубеж',
    expeditionProgress: 70,
    requiredEnergy: 70,
    expeditionStatus: 'EVENT_READY',
    expeditionVersion: 42,
    unlockedEvent: HomeExpeditionEvent(
      eventId: 'uncharted-verge-v1',
      title: 'Небо без карты',
      summary: 'На рубеже за вторым рассветом нет знакомых ориентиров.',
      status: 'READY',
      choices: <HomeEventChoice>[
        HomeEventChoice(
          choiceId: 'root-constellation-gate',
          title: 'Укоренить проход с Мхом-оплотом',
          description: 'Позволить взрослому Мху вырастить опору в пустоте.',
          pilotExperienceReward: 70,
          petBondReward: 40,
          materialReward: HomeMaterialRewardPreview(
            itemId: 'ash-seed',
            itemName: 'Пепельное семя',
            quantity: 2,
          ),
          availability: 'LOCKED',
          requirement: HomeChoiceRequirement(
            type: 'ACTIVE_PET',
            slotId: 'ACTIVE_PET',
            slotName: 'Активный питомец',
            itemId: 'moss-v1',
            itemName: 'Мох-оплот',
            minimumEvolutionStage: 2,
            description:
                'Выберите взрослого Мха-оплота активным питомцем, чтобы вырастить живой проход.',
          ),
        ),
      ],
    ),
    pilotName: 'Навигатор',
    pilotLevel: 2,
    pilotCurrentExperience: 40,
    pilotNextLevelExperience: 160,
    petName: 'Искра',
    petLevel: 2,
    petBond: 40,
  );
}

HomeSnapshot _signalReaderEventReady() {
  return const HomeSnapshot(
    localDate: '2026-07-26',
    timeZone: 'Europe/Berlin',
    dailySteps: 12000,
    dailyGoal: 3250,
    dailyGoalPolicy: _adaptiveGoalPolicy,
    availableEnergy: 0,
    activityStateVersion: 1,
    economyVersion: 8,
    lastActivitySyncAt: '2026-07-26T05:55:00Z',
    serverTime: '2026-07-26T06:00:00Z',
    contentVersion: 'chapter-1-v13',
    expeditionId: 'starter-expedition-v1',
    expeditionName: 'Сигнал из туманного сектора',
    currentNodeId: 'constellation-sanctuary',
    currentNodeName: 'Святилище созвездий',
    expeditionProgress: 80,
    requiredEnergy: 80,
    expeditionStatus: 'EVENT_READY',
    expeditionVersion: 51,
    unlockedEvent: HomeExpeditionEvent(
      eventId: 'constellation-sanctuary-v1',
      title: 'Хор трёх путей',
      summary: 'Свет, корни и эхо складываются в карту нового мира.',
      status: 'READY',
      choices: <HomeEventChoice>[
        HomeEventChoice(
          choiceId: 'decode-sanctuary-signal',
          title: 'Расшифровать скрытый хор',
          description: 'Применить Чтение сигналов к хору святилища.',
          pilotExperienceReward: 96,
          petBondReward: 50,
          materialReward: HomeMaterialRewardPreview(
            itemId: 'echo-thread',
            itemName: 'Нить эха',
            quantity: 4,
          ),
          availability: 'LOCKED',
          requirement: HomeChoiceRequirement(
            type: 'UNLOCKED_SKILL',
            slotId: 'PILOT_SKILL',
            slotName: 'Навык пилота',
            itemId: 'signal-reader',
            itemName: 'Чтение сигналов',
            description:
                'Откройте навык «Чтение сигналов», чтобы расшифровать скрытый хор святилища.',
          ),
        ),
      ],
    ),
    pilotName: 'Навигатор',
    pilotLevel: 4,
    pilotCurrentExperience: 380,
    pilotNextLevelExperience: 640,
    petName: 'Искра-звездочёт',
    petLevel: 3,
    petBond: 170,
  );
}

HomeSnapshot _hiddenSignalObservatoryReady() {
  return const HomeSnapshot(
    localDate: '2026-07-26',
    timeZone: 'Europe/Berlin',
    dailySteps: 12000,
    dailyGoal: 3250,
    dailyGoalPolicy: _adaptiveGoalPolicy,
    availableEnergy: 0,
    activityStateVersion: 1,
    economyVersion: 10,
    lastActivitySyncAt: '2026-07-26T05:55:00Z',
    serverTime: '2026-07-26T06:00:00Z',
    contentVersion: 'chapter-1-v14',
    expeditionId: 'starter-expedition-v1',
    expeditionName: 'Сигнал из туманного сектора',
    currentNodeId: 'hidden-signal-observatory',
    currentNodeName: 'Обсерватория скрытого сигнала',
    expeditionProgress: 90,
    requiredEnergy: 90,
    expeditionStatus: 'EVENT_READY',
    expeditionVersion: 53,
    unlockedEvent: HomeExpeditionEvent(
      eventId: 'hidden-signal-observatory-v1',
      title: 'Координаты за хором',
      summary: 'Скрытый хор складывается в карту неизвестного сектора.',
      status: 'READY',
      choices: <HomeEventChoice>[
        HomeEventChoice(
          choiceId: 'chart-hidden-sector',
          title: 'Нанести скрытый сектор на карту',
          description: 'Закрепить координаты для будущих экспедиций.',
          pilotExperienceReward: 112,
          petBondReward: 54,
          materialReward: HomeMaterialRewardPreview(
            itemId: 'prism-dust',
            itemName: 'Призматическая пыль',
            quantity: 4,
          ),
        ),
        HomeEventChoice(
          choiceId: 'preserve-echo-key',
          title: 'Сохранить ключ эха',
          description: 'Передать живой ритм сигнала питомцу.',
          pilotExperienceReward: 86,
          petBondReward: 76,
          materialReward: HomeMaterialRewardPreview(
            itemId: 'echo-thread',
            itemName: 'Нить эха',
            quantity: 5,
          ),
        ),
      ],
    ),
    pilotName: 'Навигатор',
    pilotLevel: 4,
    pilotCurrentExperience: 476,
    pilotNextLevelExperience: 640,
    petName: 'Искра-звездочёт',
    petLevel: 3,
    petBond: 220,
  );
}

HomeSnapshot _trailMemoryRouteLocked() {
  return const HomeSnapshot(
    localDate: '2026-07-26',
    timeZone: 'Europe/Berlin',
    dailySteps: 12000,
    dailyGoal: 3250,
    dailyGoalPolicy: _adaptiveGoalPolicy,
    availableEnergy: 0,
    activityStateVersion: 1,
    economyVersion: 10,
    lastActivitySyncAt: '2026-07-26T05:55:00Z',
    serverTime: '2026-07-26T06:00:00Z',
    contentVersion: 'chapter-1-v15',
    expeditionId: 'starter-expedition-v1',
    expeditionName: 'Сигнал из туманного сектора',
    currentNodeId: 'hidden-signal-observatory',
    currentNodeName: 'Обсерватория скрытого сигнала',
    expeditionProgress: 90,
    requiredEnergy: 90,
    expeditionStatus: 'EVENT_READY',
    expeditionVersion: 53,
    unlockedEvent: HomeExpeditionEvent(
      eventId: 'hidden-signal-observatory-v1',
      title: 'Координаты за хором',
      summary: 'Один забытый путь ещё можно восстановить.',
      status: 'READY',
      choices: <HomeEventChoice>[
        HomeEventChoice(
          choiceId: 'reconstruct-forgotten-route',
          title: 'Восстановить забытый маршрут',
          description: 'Собрать исчезнувшие шаги в новый путь.',
          pilotExperienceReward: 104,
          petBondReward: 64,
          materialReward: HomeMaterialRewardPreview(
            itemId: 'dawn-fragment',
            itemName: 'Фрагмент рассвета',
            quantity: 3,
          ),
          availability: 'LOCKED',
          requirement: HomeChoiceRequirement(
            type: 'UNLOCKED_SKILL',
            slotId: 'PILOT_SKILL',
            slotName: 'Навык пилота',
            itemId: 'trail-memory',
            itemName: 'Память маршрута',
            description:
                'Откройте навык «Память маршрута», чтобы восстановить забытый путь обсерватории.',
          ),
        ),
      ],
    ),
    pilotName: 'Навигатор',
    pilotLevel: 4,
    pilotCurrentExperience: 476,
    pilotNextLevelExperience: 640,
    petName: 'Искра-звездочёт',
    petLevel: 3,
    petBond: 220,
  );
}

HomeSnapshot _memoryConstellationReady() {
  return const HomeSnapshot(
    localDate: '2026-07-26',
    timeZone: 'Europe/Berlin',
    dailySteps: 12000,
    dailyGoal: 3250,
    dailyGoalPolicy: _adaptiveGoalPolicy,
    availableEnergy: 0,
    activityStateVersion: 1,
    economyVersion: 11,
    lastActivitySyncAt: '2026-07-26T05:55:00Z',
    serverTime: '2026-07-26T06:00:00Z',
    contentVersion: 'chapter-1-v15',
    expeditionId: 'starter-expedition-v1',
    expeditionName: 'Сигнал из туманного сектора',
    currentNodeId: 'memory-constellation',
    currentNodeName: 'Созвездие памяти',
    expeditionProgress: 95,
    requiredEnergy: 95,
    expeditionStatus: 'EVENT_READY',
    expeditionVersion: 55,
    unlockedEvent: HomeExpeditionEvent(
      eventId: 'memory-constellation-v1',
      title: 'Маршрут, который помнит шаги',
      summary: 'Забытые следы вспыхнули созвездием.',
      status: 'READY',
      choices: <HomeEventChoice>[
        HomeEventChoice(
          choiceId: 'archive-return-path',
          title: 'Сохранить путь возвращения',
          description: 'Закрепить восстановленные шаги в общей карте.',
          pilotExperienceReward: 120,
          petBondReward: 58,
          materialReward: HomeMaterialRewardPreview(
            itemId: 'ion-bloom',
            itemName: 'Ионный цветок',
            quantity: 4,
          ),
        ),
        HomeEventChoice(
          choiceId: 'entrust-memory-to-pet',
          title: 'Доверить память питомцу',
          description: 'Позволить питомцу удержать живой ритм пути.',
          pilotExperienceReward: 92,
          petBondReward: 82,
          materialReward: HomeMaterialRewardPreview(
            itemId: 'echo-thread',
            itemName: 'Нить эха',
            quantity: 6,
          ),
        ),
      ],
    ),
    pilotName: 'Навигатор',
    pilotLevel: 5,
    pilotCurrentExperience: 580,
    pilotNextLevelExperience: 1000,
    petName: 'Искра-звездочёт',
    petLevel: 4,
    petBond: 284,
  );
}

HomeSnapshot _energyDisciplineRouteLocked() {
  return const HomeSnapshot(
    localDate: '2026-07-26',
    timeZone: 'Europe/Berlin',
    dailySteps: 12000,
    dailyGoal: 3250,
    dailyGoalPolicy: _adaptiveGoalPolicy,
    availableEnergy: 0,
    activityStateVersion: 1,
    economyVersion: 12,
    lastActivitySyncAt: '2026-07-26T05:55:00Z',
    serverTime: '2026-07-26T06:00:00Z',
    contentVersion: 'chapter-1-v16',
    expeditionId: 'starter-expedition-v1',
    expeditionName: 'Сигнал из туманного сектора',
    currentNodeId: 'memory-constellation',
    currentNodeName: 'Созвездие памяти',
    expeditionProgress: 95,
    requiredEnergy: 95,
    expeditionStatus: 'EVENT_READY',
    expeditionVersion: 55,
    unlockedEvent: HomeExpeditionEvent(
      eventId: 'memory-constellation-v1',
      title: 'Маршрут, который помнит шаги',
      summary: 'Поток рассвета можно выровнять в новый меридиан.',
      status: 'READY',
      choices: <HomeEventChoice>[
        HomeEventChoice(
          choiceId: 'stabilize-dawn-current',
          title: 'Стабилизировать поток рассвета',
          description: 'Выровнять импульсы созвездия в новый меридиан.',
          pilotExperienceReward: 112,
          petBondReward: 70,
          materialReward: HomeMaterialRewardPreview(
            itemId: 'ion-bloom',
            itemName: 'Ионный цветок',
            quantity: 3,
          ),
          availability: 'LOCKED',
          requirement: HomeChoiceRequirement(
            type: 'UNLOCKED_SKILL',
            slotId: 'PILOT_SKILL',
            slotName: 'Навык пилота',
            itemId: 'energy-discipline',
            itemName: 'Дисциплина энергии',
            description:
                'Откройте навык «Дисциплина энергии», чтобы стабилизировать поток рассвета.',
          ),
        ),
      ],
    ),
    pilotName: 'Навигатор',
    pilotLevel: 5,
    pilotCurrentExperience: 580,
    pilotNextLevelExperience: 1000,
    petName: 'Искра-звездочёт',
    petLevel: 4,
    petBond: 284,
  );
}

HomeSnapshot _dawnMeridianReady() {
  return const HomeSnapshot(
    localDate: '2026-07-26',
    timeZone: 'Europe/Berlin',
    dailySteps: 12000,
    dailyGoal: 3250,
    dailyGoalPolicy: _adaptiveGoalPolicy,
    availableEnergy: 0,
    activityStateVersion: 1,
    economyVersion: 13,
    lastActivitySyncAt: '2026-07-26T05:55:00Z',
    serverTime: '2026-07-26T06:00:00Z',
    contentVersion: 'chapter-1-v15',
    expeditionId: 'starter-expedition-v1',
    expeditionName: 'Сигнал из туманного сектора',
    currentNodeId: 'dawn-meridian',
    currentNodeName: 'Меридиан рассвета',
    expeditionProgress: 100,
    requiredEnergy: 100,
    expeditionStatus: 'EVENT_READY',
    expeditionVersion: 57,
    unlockedEvent: HomeExpeditionEvent(
      eventId: 'dawn-meridian-v1',
      title: 'Ритм между шагами',
      summary: 'Поток рассвета отвечает на движение отряда.',
      status: 'READY',
      choices: <HomeEventChoice>[
        HomeEventChoice(
          choiceId: 'anchor-dawn-flow',
          title: 'Закрепить поток в маяках',
          description: 'Распределить импульс между опорными точками.',
          pilotExperienceReward: 132,
          petBondReward: 64,
          materialReward: HomeMaterialRewardPreview(
            itemId: 'dawn-fragment',
            itemName: 'Фрагмент рассвета',
            quantity: 5,
          ),
        ),
        HomeEventChoice(
          choiceId: 'share-dawn-flow-with-pet',
          title: 'Разделить поток с питомцем',
          description: 'Доверить питомцу живой ритм меридиана.',
          pilotExperienceReward: 100,
          petBondReward: 90,
          materialReward: HomeMaterialRewardPreview(
            itemId: 'echo-thread',
            itemName: 'Нить эха',
            quantity: 7,
          ),
        ),
      ],
    ),
    pilotName: 'Навигатор',
    pilotLevel: 5,
    pilotCurrentExperience: 692,
    pilotNextLevelExperience: 1000,
    petName: 'Искра-звездочёт',
    petLevel: 4,
    petBond: 354,
  );
}

HomeSnapshot _steadyStepRouteLocked() {
  return const HomeSnapshot(
    localDate: '2026-07-26',
    timeZone: 'Europe/Berlin',
    dailySteps: 12000,
    dailyGoal: 3250,
    dailyGoalPolicy: _adaptiveGoalPolicy,
    availableEnergy: 0,
    activityStateVersion: 1,
    economyVersion: 14,
    lastActivitySyncAt: '2026-07-26T05:55:00Z',
    serverTime: '2026-07-26T06:00:00Z',
    contentVersion: 'chapter-1-v17',
    expeditionId: 'starter-expedition-v1',
    expeditionName: 'Сигнал из туманного сектора',
    currentNodeId: 'dawn-meridian',
    currentNodeName: 'Меридиан рассвета',
    expeditionProgress: 100,
    requiredEnergy: 100,
    expeditionStatus: 'EVENT_READY',
    expeditionVersion: 56,
    unlockedEvent: HomeExpeditionEvent(
      eventId: 'dawn-meridian-v1',
      title: 'Ритм между шагами',
      summary: 'Первый свет собрался в подвижный переход.',
      status: 'READY',
      choices: <HomeEventChoice>[
        HomeEventChoice(
          choiceId: 'cross-first-light-causeway',
          title: 'Перейти по первому свету',
          description: 'Удержать ритм подвижного перехода.',
          pilotExperienceReward: 118,
          petBondReward: 76,
          materialReward: HomeMaterialRewardPreview(
            itemId: 'prism-dust',
            itemName: 'Призматическая пыль',
            quantity: 4,
          ),
          availability: 'LOCKED',
          requirement: HomeChoiceRequirement(
            type: 'UNLOCKED_SKILL',
            slotId: 'PILOT_SKILL',
            slotName: 'Навык пилота',
            itemId: 'steady-step',
            itemName: 'Ровный шаг',
            description:
                'Откройте навык «Ровный шаг», чтобы перейти по первому свету.',
          ),
        ),
      ],
    ),
    pilotName: 'Навигатор',
    pilotLevel: 6,
    pilotCurrentExperience: 692,
    pilotNextLevelExperience: 1200,
    petName: 'Искра-звездочёт',
    petLevel: 5,
    petBond: 354,
  );
}

HomeSnapshot _firstLightCausewayReady() {
  return const HomeSnapshot(
    localDate: '2026-07-26',
    timeZone: 'Europe/Berlin',
    dailySteps: 12000,
    dailyGoal: 3250,
    dailyGoalPolicy: _adaptiveGoalPolicy,
    availableEnergy: 0,
    activityStateVersion: 1,
    economyVersion: 15,
    lastActivitySyncAt: '2026-07-26T05:55:00Z',
    serverTime: '2026-07-26T06:00:00Z',
    contentVersion: 'chapter-1-v16',
    expeditionId: 'starter-expedition-v1',
    expeditionName: 'Сигнал из туманного сектора',
    currentNodeId: 'first-light-causeway',
    currentNodeName: 'Переход первого света',
    expeditionProgress: 105,
    requiredEnergy: 105,
    expeditionStatus: 'EVENT_READY',
    expeditionVersion: 59,
    unlockedEvent: HomeExpeditionEvent(
      eventId: 'first-light-causeway-v1',
      title: 'Шаг над рассветом',
      summary: 'Первый свет удерживает путь над меридианом.',
      status: 'READY',
      choices: <HomeEventChoice>[
        HomeEventChoice(
          choiceId: 'map-first-light-pulse',
          title: 'Нанести импульс на карту',
          description: 'Сохранить точный ритм перехода.',
          pilotExperienceReward: 144,
          petBondReward: 72,
          materialReward: HomeMaterialRewardPreview(
            itemId: 'ion-bloom',
            itemName: 'Ионный цветок',
            quantity: 6,
          ),
        ),
        HomeEventChoice(
          choiceId: 'follow-pets-steady-pace',
          title: 'Следовать ровному темпу питомца',
          description: 'Доверить питомцу живой ритм перехода.',
          pilotExperienceReward: 110,
          petBondReward: 100,
          materialReward: HomeMaterialRewardPreview(
            itemId: 'echo-thread',
            itemName: 'Нить эха',
            quantity: 8,
          ),
        ),
      ],
    ),
    pilotName: 'Навигатор',
    pilotLevel: 6,
    pilotCurrentExperience: 810,
    pilotNextLevelExperience: 1200,
    petName: 'Искра-звездочёт',
    petLevel: 5,
    petBond: 430,
  );
}

const HomeCraftingRecipe _readyRecipe = HomeCraftingRecipe(
  recipeId: 'resonance-compass-v1',
  recipeVersion: '1',
  name: 'Резонансный компас',
  description: 'Собрать прибор из трофеев экспедиции.',
  status: 'READY',
  ingredients: <HomeCraftingIngredient>[
    HomeCraftingIngredient(
      itemId: 'lumen-shard',
      name: 'Люминовый осколок',
      requiredQuantity: 2,
      availableQuantity: 2,
    ),
    HomeCraftingIngredient(
      itemId: 'echo-thread',
      name: 'Нить эха',
      requiredQuantity: 1,
      availableQuantity: 1,
    ),
  ],
  result: HomeCraftingResultPreview(
    itemId: 'resonance-compass',
    name: 'Резонансный компас',
    description: 'Уникальный прибор.',
    kind: 'UNIQUE',
  ),
);

HomeSnapshot _eventReady() {
  return const HomeSnapshot(
    localDate: '2026-07-26',
    timeZone: 'Europe/Berlin',
    dailySteps: 6842,
    dailyGoal: 3250,
    dailyGoalPolicy: _adaptiveGoalPolicy,
    availableEnergy: 38,
    activityStateVersion: 1,
    economyVersion: 2,
    lastActivitySyncAt: '2026-07-26T05:55:00Z',
    serverTime: '2026-07-26T06:00:00Z',
    contentVersion: 'chapter-1-v1',
    expeditionId: 'starter-expedition-v1',
    expeditionName: 'Сигнал из туманного сектора',
    currentNodeId: 'outer-beacon',
    currentNodeName: 'Внешний маяк',
    expeditionProgress: 30,
    requiredEnergy: 30,
    expeditionStatus: 'EVENT_READY',
    expeditionVersion: 1,
    unlockedEvent: HomeExpeditionEvent(
      eventId: 'signal-source-v1',
      title: 'Источник сигнала',
      summary: 'Маяк отвечает импульсом.',
      status: 'READY',
      choices: <HomeEventChoice>[
        HomeEventChoice(
          choiceId: 'analyze-signal',
          title: 'Проанализировать сигнал',
          description: 'Пилот сопоставит частоты маяка.',
          pilotExperienceReward: 40,
          petBondReward: 5,
        ),
        HomeEventChoice(
          choiceId: 'trust-spark',
          title: 'Довериться Искре',
          description: 'Питомец найдёт путь по свету.',
          pilotExperienceReward: 20,
          petBondReward: 15,
        ),
      ],
    ),
    pilotName: 'Навигатор',
    pilotLevel: 1,
    pilotCurrentExperience: 20,
    pilotNextLevelExperience: 100,
    petName: 'Искра',
    petLevel: 1,
    petBond: 10,
  );
}

HomeSnapshot _secondEventReady() {
  return const HomeSnapshot(
    localDate: '2026-07-26',
    timeZone: 'Europe/Berlin',
    dailySteps: 10000,
    dailyGoal: 3250,
    dailyGoalPolicy: _adaptiveGoalPolicy,
    availableEnergy: 25,
    activityStateVersion: 1,
    economyVersion: 3,
    lastActivitySyncAt: '2026-07-26T05:55:00Z',
    serverTime: '2026-07-26T06:00:00Z',
    contentVersion: 'chapter-1-v1',
    expeditionId: 'starter-expedition-v1',
    expeditionName: 'Сигнал из туманного сектора',
    currentNodeId: 'lumen-gate',
    currentNodeName: 'Люминовые ворота',
    expeditionProgress: 45,
    requiredEnergy: 45,
    expeditionStatus: 'EVENT_READY',
    expeditionVersion: 3,
    unlockedEvent: HomeExpeditionEvent(
      eventId: 'echo-vault-v1',
      title: 'Хранилище эха',
      summary: 'Ядро нестабильно.',
      status: 'READY',
      choices: <HomeEventChoice>[
        HomeEventChoice(
          choiceId: 'stabilize-core',
          title: 'Стабилизировать ядро',
          description: 'Навигатор зафиксирует резонанс.',
          pilotExperienceReward: 30,
          petBondReward: 8,
          materialReward: HomeMaterialRewardPreview(
            itemId: 'lumen-shard',
            itemName: 'Люминовый осколок',
            quantity: 2,
          ),
        ),
        HomeEventChoice(
          choiceId: 'follow-echo',
          title: 'Последовать за эхом',
          description: 'Искра найдёт живой след.',
          pilotExperienceReward: 20,
          petBondReward: 18,
          materialReward: HomeMaterialRewardPreview(
            itemId: 'echo-thread',
            itemName: 'Нить эха',
            quantity: 1,
          ),
        ),
      ],
    ),
    pilotName: 'Навигатор',
    pilotLevel: 1,
    pilotCurrentExperience: 60,
    pilotNextLevelExperience: 100,
    petName: 'Искра',
    petLevel: 1,
    petBond: 15,
  );
}

HomeSnapshot _pendingEventResultHome({
  CachedReadMetadata? cacheMetadata,
  bool includePending = true,
  bool includeReadyEvent = false,
  HomeExpeditionEvent? unlockedEvent,
  String resultPilotId = 'navigator-v1',
  String resultPetId = 'spark-v1',
}) {
  return HomeSnapshot(
    localDate: '2026-07-26',
    timeZone: 'Europe/Berlin',
    dailySteps: 10000,
    dailyGoal: 3250,
    dailyGoalPolicy: _adaptiveGoalPolicy,
    availableEnergy: 25,
    activityStateVersion: 1,
    economyVersion: 3,
    lastActivitySyncAt: '2026-07-26T05:55:00Z',
    serverTime: '2026-07-26T06:00:00Z',
    contentVersion: 'chapter-1-v1',
    expeditionId: 'starter-expedition-v1',
    expeditionName: 'Сигнал из туманного сектора',
    currentNodeId: 'ash-orbit',
    currentNodeName: 'Пепельная орбита',
    expeditionProgress: 0,
    requiredEnergy: 55,
    expeditionStatus: includeReadyEvent ? 'EVENT_READY' : 'IN_PROGRESS',
    expeditionVersion: 4,
    unlockedEvent:
        unlockedEvent ??
        (includeReadyEvent ? _secondEventReady().unlockedEvent : null),
    pilotName: 'Навигатор',
    pilotLevel: 1,
    pilotCurrentExperience: 90,
    pilotNextLevelExperience: 100,
    petName: 'Искра',
    petLevel: 1,
    petBond: 23,
    inventory: const <HomeInventoryItem>[
      HomeInventoryItem(
        itemId: 'lumen-shard',
        name: 'Люминовый осколок',
        description: 'Стабильный фрагмент светового ядра.',
        quantity: 2,
        version: 1,
      ),
    ],
    pendingEventResult: includePending
        ? PendingEventResult(
            receiptId: '22222222-2222-2222-2222-222222222222',
            eventId: 'echo-vault-v1',
            eventTitle: 'Хранилище эха',
            choiceId: 'stabilize-core',
            choiceTitle: 'Стабилизировать ядро',
            outcomeTitle: 'Стабильный резонанс',
            outcomeSummary: 'Ядро перестало разрушаться.',
            pilot: EventPilotReward(
              pilotId: resultPilotId,
              name: 'Навигатор',
              level: 1,
              experienceGained: 30,
              currentExperience: 90,
              nextLevelExperience: 100,
              version: 2,
            ),
            pet: EventPetReward(
              petId: resultPetId,
              name: 'Искра',
              level: 1,
              bondGained: 8,
              bond: 23,
              version: 2,
            ),
            material: const EventMaterialReward(
              itemId: 'lumen-shard',
              name: 'Люминовый осколок',
              description: 'Стабильный фрагмент светового ядра.',
              quantityGained: 2,
              quantityAfter: 2,
              version: 1,
            ),
            nextNode: const EventNextNode(
              nodeId: 'ash-orbit',
              name: 'Пепельная орбита',
            ),
            resolvedAt: '2026-07-26T06:00:00Z',
          )
        : null,
    cacheMetadata: cacheMetadata,
  );
}

HomeSnapshot _acknowledgedEventResultHome() {
  return _pendingEventResultHome(includePending: false);
}

ExpeditionAdvanceResult _advanceResult({
  ExpeditionEventResult unlockedEvent = const ExpeditionEventResult(
    eventId: 'signal-source-v1',
    title: 'Источник сигнала',
    summary: 'Маяк отвечает импульсом.',
    status: 'READY',
  ),
}) {
  return ExpeditionAdvanceResult(
    contentVersion: 'chapter-1-v1',
    expeditionId: 'starter-expedition-v1',
    expeditionName: 'Сигнал из туманного сектора',
    energySpent: 30,
    energyBalanceAfter: 38,
    economyVersion: 2,
    progressAfter: 30,
    requiredEnergy: 30,
    expeditionVersion: 1,
    status: 'EVENT_READY',
    currentNodeId: 'outer-beacon',
    currentNodeName: 'Внешний маяк',
    unlockedEvent: unlockedEvent,
    serverTime: '2026-07-26T06:00:00Z',
  );
}

EventResolutionResult _eventResolutionResult() {
  return const EventResolutionResult(
    receiptId: '22222222-2222-2222-2222-222222222222',
    handoffRequired: true,
    contentVersion: 'chapter-1-v1',
    expeditionId: 'starter-expedition-v1',
    expeditionStatus: 'IN_PROGRESS',
    expeditionVersion: 4,
    eventId: 'echo-vault-v1',
    eventTitle: 'Хранилище эха',
    status: 'RESOLVED',
    choiceId: 'stabilize-core',
    choiceTitle: 'Стабилизировать ядро',
    outcomeTitle: 'Стабильный резонанс',
    outcomeSummary: 'Ядро перестало разрушаться.',
    pilot: EventPilotReward(
      pilotId: 'navigator-v1',
      name: 'Навигатор',
      level: 1,
      experienceGained: 30,
      currentExperience: 90,
      nextLevelExperience: 100,
      version: 2,
    ),
    pet: EventPetReward(
      petId: 'spark-v1',
      name: 'Искра',
      level: 1,
      bondGained: 8,
      bond: 23,
      version: 2,
    ),
    material: EventMaterialReward(
      itemId: 'lumen-shard',
      name: 'Люминовый осколок',
      description: 'Стабильный фрагмент светового ядра.',
      quantityGained: 2,
      quantityAfter: 2,
      version: 1,
    ),
    nextNode: EventNextNode(nodeId: 'ash-orbit', name: 'Пепельная орбита'),
    serverTime: '2026-07-26T06:00:00Z',
  );
}

CraftingResult _craftingResult() {
  return const CraftingResult(
    contentVersion: 'crafting-v1',
    recipeId: 'resonance-compass-v1',
    recipeVersion: '1',
    recipeName: 'Резонансный компас',
    consumedIngredients: <CraftingIngredientResult>[
      CraftingIngredientResult(
        itemId: 'lumen-shard',
        name: 'Люминовый осколок',
        quantityConsumed: 2,
        quantityAfter: 0,
        version: 2,
      ),
      CraftingIngredientResult(
        itemId: 'echo-thread',
        name: 'Нить эха',
        quantityConsumed: 1,
        quantityAfter: 0,
        version: 2,
      ),
    ],
    craftedItem: CraftedUniqueItem(
      itemInstanceId: '33333333-3333-3333-3333-333333333333',
      itemId: 'resonance-compass',
      name: 'Резонансный компас',
      description: 'Уникальный прибор.',
      version: 1,
      craftedAt: '2026-07-26T06:00:00Z',
    ),
    serverTime: '2026-07-26T06:00:00Z',
  );
}

ItemUpgradeResult _itemUpgradeResult() {
  return const ItemUpgradeResult(
    contentVersion: 'item-upgrade-v2',
    upgradeId: 'prism-sextant-second-dawn-attunement-v1',
    upgradeVersion: '1',
    upgradeName: 'Настроить секстант на второй рассвет',
    consumedIngredients: <ItemUpgradeIngredientResult>[
      ItemUpgradeIngredientResult(
        itemId: 'echo-thread',
        name: 'Нить эха',
        quantityConsumed: 2,
        quantityAfter: 0,
        version: 2,
      ),
      ItemUpgradeIngredientResult(
        itemId: 'ion-bloom',
        name: 'Ионный цветок',
        quantityConsumed: 2,
        quantityAfter: 0,
        version: 2,
      ),
      ItemUpgradeIngredientResult(
        itemId: 'dawn-fragment',
        name: 'Фрагмент рассвета',
        quantityConsumed: 2,
        quantityAfter: 0,
        version: 2,
      ),
    ],
    upgradedItem: UpgradedUniqueItem(
      itemInstanceId: '44444444-4444-4444-4444-444444444444',
      itemId: 'prism-sextant',
      name: 'Призматический секстант',
      description: 'Уникальный навигационный прибор.',
      previousLevel: 2,
      upgradeLevel: 3,
      rarity: 'EPIC',
      upgradedAt: '2026-07-26T06:00:00Z',
    ),
    serverTime: '2026-07-26T06:00:00Z',
  );
}

EquipmentResult _equipmentResult({required String action}) {
  return EquipmentResult(
    contentVersion: 'equipment-v1',
    slotId: 'NAVIGATION',
    slotName: 'Навигационный прибор',
    slotDescription: 'Инструмент, влияющий на доступные маршруты.',
    action: action,
    changed: true,
    version: action == 'EQUIP' ? 1 : 2,
    equippedItem: action == 'EQUIP'
        ? const EquippedItem(
            itemInstanceId: '33333333-3333-3333-3333-333333333333',
            itemId: 'resonance-compass',
            name: 'Резонансный компас',
            description: 'Уникальный навигационный прибор.',
            equippedAt: '2026-07-26T06:00:00Z',
          )
        : null,
    serverTime: '2026-07-26T06:00:00Z',
  );
}
