import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/core/cache/read_snapshot_cache.dart';
import 'package:walking_rpg_mobile/core/navigation/navigation_chrome_insets.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';
import 'package:walking_rpg_mobile/features/crew/presentation/crew_screen.dart';
import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';
import 'package:walking_rpg_mobile/features/platform/domain/platform_snapshot.dart';

import 'support/platform_fixture.dart';

void main() {
  testWidgets('renders the complete pilot and companion workspace', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        home: CrewScreen(
          loader: () async => platformSnapshot(),
          homeLoader: () async => HomeSnapshot.demo,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('crew-hero')), findsOneWidget);
    expect(find.byKey(const Key('crew-portrait-stage')), findsOneWidget);
    expect(find.byIcon(Icons.link), findsOneWidget);
    expect(find.byKey(const Key('crew-pilot-card')), findsOneWidget);
    expect(find.byKey(const Key('crew-pilot-xp-progress')), findsOneWidget);

    final Finder scrollable = find
        .descendant(
          of: find.byKey(const Key('crew-screen-list')),
          matching: find.byType(Scrollable),
        )
        .first;
    for (final Key key in const <Key>[
      Key('crew-active-pet-card'),
      Key('crew-pet-spark-v1'),
      Key('crew-pet-moss-v1'),
      Key('crew-pet-rune-v1'),
      Key('crew-skills-card'),
      Key('crew-equipment-card'),
      Key('crew-cosmetic-pilot-scarf'),
      Key('crew-cosmetic-spark-halo'),
    ]) {
      await tester.scrollUntilVisible(
        find.byKey(key),
        320,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(key), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('selects a companion through the shared platform command', (
    WidgetTester tester,
  ) async {
    String? command;
    Map<String, Object?>? sentPayload;
    String? sentIdempotencyKey;
    bool stateChanged = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        home: CrewScreen(
          loader: () async => platformSnapshot(),
          homeLoader: () async => HomeSnapshot.demo,
          idempotencyKeyFactory: (String _) => 'crew-command-key',
          onServerStateChanged: () {
            stateChanged = true;
          },
          commandExecutor:
              ({
                required String commandType,
                required Map<String, Object?> payload,
                required String idempotencyKey,
              }) async {
                command = commandType;
                sentPayload = payload;
                sentIdempotencyKey = idempotencyKey;
                return platformCommandResult(
                  commandType: commandType,
                  idempotencyKey: idempotencyKey,
                  snapshot: platformSnapshot(
                    stateVersion: 4,
                    activePetId: 'moss-v1',
                  ),
                );
              },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder selectMoss = find.byKey(const Key('crew-select-pet-moss-v1'));
    await tester.scrollUntilVisible(selectMoss, 300);
    await tester.tap(selectMoss);
    await tester.pumpAndSettle();

    expect(command, 'SELECT_PET');
    expect(sentPayload, <String, Object?>{'petId': 'moss-v1'});
    expect(sentIdempotencyKey, 'crew-command-key');
    expect(stateChanged, isTrue);
    expect(find.byKey(const Key('crew-select-pet-moss-v1')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps Platform commands enabled with a cached Home snapshot', (
    WidgetTester tester,
  ) async {
    int commands = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        home: CrewScreen(
          loader: () async => platformSnapshot(),
          homeLoader: () async => _cachedHomeSnapshot(),
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
                  snapshot: platformSnapshot(activePetId: 'moss-v1'),
                );
              },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder selectMoss = find.byKey(const Key('crew-select-pet-moss-v1'));
    await tester.scrollUntilVisible(selectMoss, 300);
    await tester.tap(selectMoss);
    await tester.pumpAndSettle();

    expect(commands, 1);
    expect(find.byKey(const Key('crew-select-pet-moss-v1')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps an accepted command when the Home refresh fails', (
    WidgetTester tester,
  ) async {
    int homeLoads = 0;
    bool stateChanged = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        home: CrewScreen(
          loader: () async => platformSnapshot(),
          homeLoader: () async {
            homeLoads += 1;
            if (homeLoads > 1) {
              throw StateError('Home refresh failed');
            }
            return HomeSnapshot.demo;
          },
          onServerStateChanged: () {
            stateChanged = true;
          },
          commandExecutor:
              ({
                required String commandType,
                required Map<String, Object?> payload,
                required String idempotencyKey,
              }) async {
                return platformCommandResult(
                  commandType: commandType,
                  idempotencyKey: idempotencyKey,
                  snapshot: platformSnapshot(
                    stateVersion: 4,
                    activePetId: 'moss-v1',
                  ),
                );
              },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder selectMoss = find.byKey(const Key('crew-select-pet-moss-v1'));
    await tester.scrollUntilVisible(selectMoss, 300);
    await tester.tap(selectMoss);
    await tester.pumpAndSettle();

    expect(homeLoads, 2);
    expect(stateChanged, isTrue);
    expect(find.byKey(const Key('crew-select-pet-moss-v1')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('handles both concurrent snapshot failures', (
    WidgetTester tester,
  ) async {
    final Completer<PlatformSnapshot> platform = Completer<PlatformSnapshot>();
    final Completer<HomeSnapshot> home = Completer<HomeSnapshot>();

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        home: CrewScreen(
          loader: () => platform.future,
          homeLoader: () => home.future,
        ),
      ),
    );

    home.completeError(StateError('Home failed first'));
    await tester.pump();
    platform.completeError(StateError('Platform failed second'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('crew-error-state')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reserves the navigation dock below crew content', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        home: NavigationChromeInsets(
          bottomDockInset: 120,
          child: CrewScreen(
            loader: () async => platformSnapshot(),
            homeLoader: () async => HomeSnapshot.demo,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final ListView list = tester.widget<ListView>(
      find.byKey(const Key('crew-screen-list')),
    );
    expect(list.padding, const EdgeInsets.fromLTRB(16, 16, 16, 156));
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact enlarged text keeps crew actions usable', (
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
        home: CrewScreen(
          loader: () async => platformSnapshot(
            ownedCosmetics: const <String>['pilot-scarf', 'spark-halo'],
          ),
          homeLoader: () async => HomeSnapshot.demo,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.byKey(const Key('crew-equip-cosmetic-spark-halo')),
      360,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(
      find.byKey(const Key('crew-equip-cosmetic-spark-halo')),
      findsOneWidget,
    );
  });
}

HomeSnapshot _cachedHomeSnapshot() {
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
    expeditionStatus: demo.expeditionStatus,
    expeditionVersion: demo.expeditionVersion,
    unlockedEvent: demo.unlockedEvent,
    pilotName: demo.pilotName,
    pilotLevel: demo.pilotLevel,
    pilotCurrentExperience: demo.pilotCurrentExperience,
    pilotNextLevelExperience: demo.pilotNextLevelExperience,
    petName: demo.petName,
    petLevel: demo.petLevel,
    petBond: demo.petBond,
    equipment: demo.equipment,
    cacheMetadata: CachedReadMetadata(
      cachedAt: DateTime.utc(2026, 8, 31, 13),
      reason: 'Home unavailable',
    ),
  );
}
