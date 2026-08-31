import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/design_system/expedition_progress_signal.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';
import 'package:walking_rpg_mobile/features/activity/domain/activity_sync_result.dart';
import 'package:walking_rpg_mobile/features/activity/presentation/activity_sync_shell.dart';
import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';
import 'package:walking_rpg_mobile/features/home/presentation/home_screen.dart';
import 'package:walking_rpg_mobile/l10n/generated/app_localizations.dart';

import 'support/platform_fixture.dart';

void main() {
  testWidgets('activity sync reloads authoritative home state', (
    WidgetTester tester,
  ) async {
    int loads = 0;
    int syncCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ActivitySyncShell(
          synchronizer: () async {
            syncCalls += 1;
            return const ActivitySyncResult(
              acceptedTotal: 6842,
              acceptedDelta: 6842,
              energyGranted: 68,
              energyBalanceAfter: 68,
              economyVersion: 1,
              riskStatus: 'ACCEPTED',
              stateVersion: 1,
              serverTime: '2026-07-26T07:00:00Z',
            );
          },
          homeBuilder: (Key key) => HomeScreen(
            key: key,
            loader: () async {
              loads += 1;
              return loads == 1 ? _beforeSync() : _afterSync();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder syncButton = find.byKey(const Key('activity-sync-button'));
    expect(syncButton, findsOneWidget);
    await tester.tap(syncButton);
    await tester.pumpAndSettle();

    expect(syncCalls, 1);
    expect(loads, 2);
    expect(find.text('Сегодня: 6842 / 6000'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Доступная энергия: 68 · версия 1'),
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Доступная энергия: 68 · версия 1'), findsOneWidget);
  });

  testWidgets('activity sync shares the Home action dock without an overlay', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        home: ActivitySyncShell(
          synchronizer: () async => _syncResult(),
          homeLoader: () async => HomeSnapshot.demo,
          platformLoader: () async => platformSnapshot(),
          platformHomeLoader: () async => HomeSnapshot.demo,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder actionDock = find.byKey(const Key('home-sticky-action-panel'));
    final Finder syncButton = find.byKey(const Key('activity-sync-button'));
    expect(syncButton, findsOneWidget);
    expect(
      find.descendant(of: actionDock, matching: syncButton),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('activity-sync-standalone-panel')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('defers Crew requests until the destination is opened', (
    WidgetTester tester,
  ) async {
    int platformLoads = 0;
    int platformHomeLoads = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        home: ActivitySyncShell(
          synchronizer: () async => _syncResult(),
          homeLoader: () async => HomeSnapshot.demo,
          platformLoader: () async {
            platformLoads += 1;
            return platformSnapshot();
          },
          platformHomeLoader: () async {
            platformHomeLoads += 1;
            return HomeSnapshot.demo;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The mounted Journal owns the first pair; Crew must not add another pair.
    expect(platformLoads, 1);
    expect(platformHomeLoads, 1);
    expect(
      find.byKey(const Key('crew-deferred'), skipOffstage: false),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('navigation-crew')));
    await tester.pumpAndSettle();

    expect(platformLoads, 2);
    expect(platformHomeLoads, 2);
    expect(find.byKey(const Key('crew-hero')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('full Home supports compact enlarged text without overflow', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final SemanticsHandle semantics = tester.ensureSemantics();
    int homeLoads = 0;
    bool accountOpened = false;

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
        home: ActivitySyncShell(
          synchronizer: () async => _syncResult(),
          homeLoader: () async {
            homeLoads += 1;
            return HomeSnapshot.demo;
          },
          platformLoader: () async => platformSnapshot(),
          platformHomeLoader: () async => HomeSnapshot.demo,
          onOpenAccount: () {
            accountOpened = true;
          },
          onOpenRecovery: () {},
          recoveryCount: 2,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-more-actions')), findsOneWidget);
    expect(find.byTooltip('Обновить'), findsNothing);
    expect(find.byTooltip('Аккаунт'), findsNothing);
    expect(
      find.byKey(const Key('home-daily-progress-compact')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('home-route-energy-compact')), findsOneWidget);
    expect(find.byType(ExpeditionProgressSignal), findsOneWidget);
    expect(
      find.byKey(
        const Key(
          'expedition-progress-signal-starter-expedition-v1-outerBeacon',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('home-expedition-team-compact')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('home-sticky-action-panel')), findsOneWidget);
    expect(find.byKey(const Key('navigation-home')), findsOneWidget);

    final double pilotTop = tester
        .getTopLeft(find.byKey(const Key('home-pilot-card')))
        .dy;
    final double petTop = tester
        .getTopLeft(find.byKey(const Key('home-pet-card')))
        .dy;
    expect(petTop, greaterThan(pilotTop));

    await tester.tap(find.byKey(const Key('home-more-actions')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-menu-refresh')));
    await tester.pumpAndSettle();
    expect(homeLoads, 2);

    await tester.tap(find.byKey(const Key('home-more-actions')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-menu-account')));
    await tester.pump();
    expect(accountOpened, isTrue);

    final Object? exception = tester.takeException();
    if (exception != null) {
      fail(
        exception is FlutterError
            ? exception.toStringDeep()
            : exception.toString(),
      );
    }

    semantics.dispose();
  });

  testWidgets('activity sync remains visible across Home read states', (
    WidgetTester tester,
  ) async {
    final Completer<HomeSnapshot> homeResult = Completer<HomeSnapshot>();
    final Completer<ActivitySyncResult> syncResult =
        Completer<ActivitySyncResult>();

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        home: ActivitySyncShell(
          synchronizer: () => syncResult.future,
          homeLoader: () => homeResult.future,
          platformLoader: () async => platformSnapshot(),
          platformHomeLoader: () async => HomeSnapshot.demo,
        ),
      ),
    );
    await tester.pump();

    final Finder actionDock = find.byKey(const Key('home-sticky-action-panel'));
    final Finder syncButton = find.byKey(const Key('activity-sync-button'));
    expect(find.byKey(const Key('home-loading-state')), findsOneWidget);
    expect(
      find.descendant(of: actionDock, matching: syncButton),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('activity-sync-standalone-panel')),
      findsNothing,
    );

    await tester.tap(syncButton);
    await tester.pump();

    expect(find.text('Синхронизация шагов...'), findsOneWidget);
    expect(find.byKey(const Key('command-recovery-progress')), findsOneWidget);

    homeResult.completeError(StateError('Backend недоступен'));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('home-error-state')), findsOneWidget);
    expect(
      find.descendant(of: actionDock, matching: syncButton),
      findsOneWidget,
    );
    expect(find.byKey(const Key('command-recovery-progress')), findsOneWidget);
    expect(tester.takeException(), isNull);

    syncResult.complete(_syncResult());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-error-state')), findsOneWidget);
    expect(find.byKey(const Key('activity-sync-button')), findsOneWidget);
    expect(find.byKey(const Key('command-recovery-progress')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('standalone activity sync action supports compact text', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final SemanticsHandle semantics = tester.ensureSemantics();
    final Completer<ActivitySyncResult> result =
        Completer<ActivitySyncResult>();

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
        home: ActivitySyncShell(
          synchronizer: () => result.future,
          homeBuilder: (Key key) => Scaffold(
            key: key,
            body: const Center(child: Text('Полевой экран')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder standalonePanel = find.byKey(
      const Key('activity-sync-standalone-panel'),
    );
    final Finder syncButton = find.byKey(const Key('activity-sync-button'));
    expect(standalonePanel, findsOneWidget);
    expect(syncButton, findsOneWidget);
    expect(find.text('Synchronize steps'), findsOneWidget);
    expect(find.byKey(const Key('home-sticky-action-panel')), findsNothing);
    expect(tester.getSize(standalonePanel).width, lessThanOrEqualTo(288));
    expect(tester.takeException(), isNull);

    await tester.tap(syncButton);
    await tester.pump();

    final Text busyLabel = tester.widget<Text>(
      find.text('Synchronizing steps...'),
    );
    expect(busyLabel.maxLines, 2);
    expect(busyLabel.overflow, TextOverflow.visible);
    final Semantics status = tester.widget<Semantics>(
      find.byKey(const Key('activity-sync-status')),
    );
    expect(status.properties.liveRegion, isTrue);
    expect(find.byKey(const Key('command-recovery-progress')), findsOneWidget);
    expect(tester.takeException(), isNull);

    result.complete(_syncResult());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    semantics.dispose();
  });

  testWidgets('test activity control is absent without an explicit source', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ActivitySyncShell(
          homeBuilder: (Key key) =>
              HomeScreen(key: key, loader: () async => HomeSnapshot.demo),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('activity-sync-button')), findsNothing);
  });
}

ActivitySyncResult _syncResult() {
  return const ActivitySyncResult(
    acceptedTotal: 6842,
    acceptedDelta: 6842,
    energyGranted: 68,
    energyBalanceAfter: 68,
    economyVersion: 1,
    riskStatus: 'ACCEPTED',
    stateVersion: 1,
    serverTime: '2026-07-26T07:00:00Z',
  );
}

HomeSnapshot _beforeSync() {
  return const HomeSnapshot(
    localDate: '2026-07-26',
    timeZone: 'Europe/Berlin',
    dailySteps: 0,
    dailyGoal: 6000,
    availableEnergy: 0,
    activityStateVersion: 0,
    economyVersion: 0,
    lastActivitySyncAt: null,
    serverTime: '2026-07-26T07:00:00Z',
    contentVersion: 'starter-v1',
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
  );
}

HomeSnapshot _afterSync() {
  return const HomeSnapshot(
    localDate: '2026-07-26',
    timeZone: 'Europe/Berlin',
    dailySteps: 6842,
    dailyGoal: 6000,
    availableEnergy: 68,
    activityStateVersion: 1,
    economyVersion: 1,
    lastActivitySyncAt: '2026-07-26T07:00:00Z',
    serverTime: '2026-07-26T07:00:01Z',
    contentVersion: 'starter-v1',
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
  );
}
