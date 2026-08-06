import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/core/cache/read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/design_system/expedition_progress_signal.dart';
import 'package:walking_rpg_mobile/design_system/expedition_ui.dart';
import 'package:walking_rpg_mobile/design_system/first_journey_route_signal.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';
import 'package:walking_rpg_mobile/features/activity/domain/activity_sync_result.dart';
import 'package:walking_rpg_mobile/features/event/domain/event_resolution_result.dart';
import 'package:walking_rpg_mobile/features/onboarding/domain/first_journey_progress.dart';
import 'package:walking_rpg_mobile/features/onboarding/presentation/first_journey_screen.dart';

import 'support/first_journey_fixture.dart';
import 'support/platform_fixture.dart';

void main() {
  testWidgets('first journey field signals stay complete on compact text', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final SemanticsHandle semantics = tester.ensureSemantics();
    const String notice =
        'Отложенная команда ждёт соединения и будет проверена без второй '
        'награды.';
    const String error =
        'Команда подтверждена, но актуальное состояние маршрута не загрузилось.';
    final FirstJourneyProgress progress = FirstJourneyProgress(
      home: firstJourneyHome(
        cacheMetadata: CachedReadMetadata(
          cachedAt: DateTime.utc(2026, 8, 2, 18),
          reason: 'Нет соединения с сервером',
        ),
      ),
      platform: platformSnapshot(
        completedOnboardingSteps: const <String>[],
        resolvedEventCount: 0,
        totalAcceptedSteps: 0,
      ),
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
        home: FirstJourneyScreen(
          progress: progress,
          busy: false,
          onWelcome: () {},
          onSync: () {},
          onSelectPet: (_) {},
          onAdvance: () {},
          onResolve: (_) {},
          onContinueAfterActivity: () {},
          onFinish: () {},
          onContinueLater: () {},
          notice: notice,
          errorMessage: error,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ExpeditionNotice), findsNWidgets(3));
    expect(find.text('СОХРАНЁННЫЙ ПУТЬ'), findsOneWidget);
    expect(find.text('СИГНАЛ МАРШРУТА'), findsOneWidget);
    expect(find.text('СОСТОЯНИЕ ТРЕБУЕТ ПРОВЕРКИ'), findsOneWidget);
    expect(find.text(notice), findsOneWidget);
    expect(find.text(error), findsOneWidget);

    final ExpeditionNotice saved = tester.widget<ExpeditionNotice>(
      find.byKey(const Key('first-journey-read-only-signal')),
    );
    final ExpeditionNotice info = tester.widget<ExpeditionNotice>(
      find.byKey(const Key('first-journey-notice-signal')),
    );
    final ExpeditionNotice uncertain = tester.widget<ExpeditionNotice>(
      find.byKey(const Key('first-journey-error-signal')),
    );
    expect(saved.tone, ExpeditionNoticeTone.neutral);
    expect(info.tone, ExpeditionNoticeTone.lumen);
    expect(uncertain.tone, ExpeditionNoticeTone.resonance);

    for (final Key key in <Key>[
      const Key('first-journey-read-only-signal'),
      const Key('first-journey-notice-signal'),
      const Key('first-journey-error-signal'),
    ]) {
      final Semantics liveSignal = tester
          .widgetList<Semantics>(
            find.descendant(
              of: find.byKey(key),
              matching: find.byType(Semantics),
            ),
          )
          .firstWhere(
            (Semantics widget) =>
                widget.container && widget.properties.liveRegion == true,
          );
      expect(liveSignal.properties.liveRegion, isTrue);
    }

    final Text errorLabel = tester.widget<Text>(
      find.text('СОСТОЯНИЕ ТРЕБУЕТ ПРОВЕРКИ'),
    );
    expect(errorLabel.maxLines, isNull);
    expect(errorLabel.overflow, TextOverflow.visible);
    expect(tester.takeException(), isNull);

    semantics.dispose();
  });

  testWidgets('full first journey supports compact enlarged text', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final SemanticsHandle semantics = tester.ensureSemantics();
    bool accountOpened = false;
    bool recoveryOpened = false;

    final FirstJourneyProgress welcome = _progress(
      completedSteps: const <String>[],
    );
    await _pumpCompactJourney(
      tester,
      progress: welcome,
      onOpenAccount: () {
        accountOpened = true;
      },
      onOpenRecovery: () {
        recoveryOpened = true;
      },
    );

    expect(
      find.byKey(const Key('first-journey-progress-compact')),
      findsOneWidget,
    );
    expect(find.byType(FirstJourneyRouteSignal), findsOneWidget);
    expect(
      find.byKey(const Key('first-journey-route-signal-0-6')),
      findsOneWidget,
    );
    expect(find.text('0/6 ЭТАПОВ ПРОЙДЕНО'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Первый путь: завершено 0 из 6 этапов'),
      findsNothing,
    );
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(
      find.byKey(const Key('first-journey-panel-compact')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('first-journey-more-actions')), findsOneWidget);
    expect(find.byTooltip('Аккаунт'), findsNothing);
    _expectNoLayoutException(tester);

    await tester.tap(find.byKey(const Key('first-journey-recovery')));
    expect(recoveryOpened, isTrue);
    await tester.tap(find.byKey(const Key('first-journey-more-actions')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('first-journey-menu-account')));
    await tester.pump();
    expect(accountOpened, isTrue);

    await _bringIntoView(tester, find.byKey(const Key('first-journey-start')));
    await _bringIntoView(
      tester,
      find.byKey(const Key('first-journey-continue-later')),
    );
    _expectNoLayoutException(tester);

    await _pumpCompactJourney(
      tester,
      progress: _progress(completedSteps: const <String>['welcome']),
    );
    expect(
      find.byKey(const Key('first-journey-route-signal-1-6')),
      findsOneWidget,
    );
    expect(find.text('1/6 ЭТАПОВ ПРОЙДЕНО'), findsOneWidget);
    await _bringIntoView(tester, find.byKey(const Key('first-journey-sync')));
    _expectNoLayoutException(tester);

    await _pumpCompactJourney(
      tester,
      progress: _progress(completedSteps: const <String>['welcome']),
      activityReward: firstJourneyActivityResult,
    );
    await _bringIntoView(
      tester,
      find.byKey(const Key('first-journey-activity-continue')),
    );
    _expectNoLayoutException(tester);

    await _pumpCompactJourney(
      tester,
      progress: _progress(
        completedSteps: const <String>['welcome'],
        synced: true,
        energy: 30,
      ),
    );
    for (final String petId in const <String>[
      'spark-v1',
      'moss-v1',
      'rune-v1',
    ]) {
      await _bringIntoView(
        tester,
        find.byKey(Key('first-journey-pet-compact-$petId')),
      );
      _expectNoLayoutException(tester);
    }

    await _pumpCompactJourney(
      tester,
      progress: _progress(
        completedSteps: const <String>['welcome', 'pet-selection'],
        synced: true,
        energy: 30,
      ),
    );
    await _bringIntoView(
      tester,
      find.byKey(const Key('first-journey-advance')),
    );
    expect(find.byType(ExpeditionProgressSignal), findsOneWidget);
    expect(
      find.byKey(
        const Key(
          'expedition-progress-signal-starter-expedition-v1-outerBeacon',
        ),
      ),
      findsOneWidget,
    );
    _expectNoLayoutException(tester);

    final FirstJourneyProgress event = _progress(
      completedSteps: const <String>['welcome', 'pet-selection'],
      synced: true,
      eventReady: true,
    );
    await _pumpCompactJourney(tester, progress: event);
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
    for (final String choiceId in const <String>[
      'analyze-signal',
      'trust-companion',
    ]) {
      await _bringIntoView(
        tester,
        find.byKey(Key('first-journey-choice-$choiceId')),
      );
      _expectNoLayoutException(tester);
    }

    await _pumpCompactJourney(
      tester,
      progress: event,
      eventReward: firstJourneyResolutionResult(),
    );
    expect(
      find.byKey(const Key('event-scene-signal-source-v1')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key(
          'event-choice-signal-signal-source-v1-analyze-signal-'
          'frequency-active',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('expedition-next-node-signal-lumen-gate-lumenGate')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Следующий узел «Люминовые ворота»'),
      findsOneWidget,
    );
    await _bringIntoView(tester, find.byKey(const Key('first-journey-finish')));
    await _bringIntoView(
      tester,
      find.byKey(const Key('first-journey-continue-later')),
    );
    _expectNoLayoutException(tester);
    semantics.dispose();
  });
}

FirstJourneyProgress _progress({
  required List<String> completedSteps,
  bool synced = false,
  int energy = 0,
  bool eventReady = false,
}) {
  return FirstJourneyProgress(
    home: firstJourneyHome(
      synced: synced,
      energy: energy,
      eventReady: eventReady,
    ),
    platform: platformSnapshot(
      completedOnboardingSteps: completedSteps,
      resolvedEventCount: 0,
      totalAcceptedSteps: synced ? 3000 : 0,
      hasSuccessfulActivitySync: synced,
    ),
  );
}

Future<void> _pumpCompactJourney(
  WidgetTester tester, {
  required FirstJourneyProgress progress,
  ActivitySyncResult? activityReward,
  EventResolutionResult? eventReward,
  VoidCallback? onOpenAccount,
  VoidCallback? onOpenRecovery,
}) async {
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
      home: FirstJourneyScreen(
        progress: progress,
        busy: false,
        onWelcome: () {},
        onSync: () {},
        onSelectPet: (_) {},
        onAdvance: () {},
        onResolve: (_) {},
        onContinueAfterActivity: () {},
        onFinish: () {},
        onContinueLater: () {},
        onOpenAccount: onOpenAccount,
        onOpenRecovery: onOpenRecovery,
        recoveryCount: 2,
        activityReward: activityReward,
        eventReward: eventReward,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _bringIntoView(WidgetTester tester, Finder target) async {
  expect(target, findsOneWidget);
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
