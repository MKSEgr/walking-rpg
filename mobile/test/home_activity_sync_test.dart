import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/features/activity/domain/activity_sync_result.dart';
import 'package:walking_rpg_mobile/features/activity/presentation/activity_sync_shell.dart';
import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';
import 'package:walking_rpg_mobile/features/home/presentation/home_screen.dart';

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
