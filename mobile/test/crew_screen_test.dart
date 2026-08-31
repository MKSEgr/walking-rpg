import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';
import 'package:walking_rpg_mobile/features/crew/presentation/crew_screen.dart';
import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';
import 'package:walking_rpg_mobile/features/platform/domain/platform_command_result.dart';

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
    expect(find.byKey(const Key('crew-pilot-card')), findsOneWidget);
    expect(find.byKey(const Key('crew-active-pet-card')), findsOneWidget);
    expect(find.byKey(const Key('crew-pilot-xp-progress')), findsOneWidget);

    final Finder scrollable = find
        .descendant(
          of: find.byKey(const Key('crew-screen-list')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('crew-cosmetic-spark-halo')),
      420,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('crew-pet-spark-v1')), findsOneWidget);
    expect(find.byKey(const Key('crew-pet-moss-v1')), findsOneWidget);
    expect(find.byKey(const Key('crew-pet-rune-v1')), findsOneWidget);
    expect(find.byKey(const Key('crew-skills-card')), findsOneWidget);
    expect(find.byKey(const Key('crew-equipment-card')), findsOneWidget);
    expect(find.byKey(const Key('crew-cosmetic-pilot-scarf')), findsOneWidget);
    expect(find.byKey(const Key('crew-cosmetic-spark-halo')), findsOneWidget);
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

    await tester.scrollUntilVisible(
      find.byKey(const Key('crew-equip-cosmetic-spark-halo')),
      360,
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('crew-equip-cosmetic-spark-halo')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
