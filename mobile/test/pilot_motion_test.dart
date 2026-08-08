import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/design_system/character_cosmetics.dart';
import 'package:walking_rpg_mobile/design_system/pilot_motion.dart';
import 'package:walking_rpg_mobile/design_system/pilot_portrait.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

void main() {
  test('maps pilot clips and look directions to the shared atlas contract', () {
    expect(PilotMotionClip.idle.row, 0);
    expect(PilotMotionClip.idle.frameCount, 6);
    expect(PilotMotionClip.runRight.row, 1);
    expect(PilotMotionClip.runLeft.row, 2);
    expect(PilotMotionClip.inspect.row, 8);
    expect(PilotLookDirection.north.row, 9);
    expect(PilotLookDirection.north.column, 0);
    expect(PilotLookDirection.south.row, 10);
    expect(PilotLookDirection.south.column, 0);
    expect(PilotLookDirection.northNorthWest.column, 7);
    expect(PilotLookDirection.northNorthWest.degrees, 337.5);
  });

  testWidgets('renders the exact Navigator pilot from the motion atlas', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        home: const Scaffold(
          body: PilotMotionPortrait(
            key: Key('navigator-motion'),
            pilotId: PilotMotionPortrait.navigatorPilotId,
            name: 'Навигатор',
            highlighted: true,
          ),
        ),
      ),
    );
    await tester.pump();

    final PilotMotionPortrait portrait = tester.widget<PilotMotionPortrait>(
      find.byKey(const Key('navigator-motion')),
    );
    final Image image = tester.widget<Image>(find.byType(Image));
    final AssetImage asset = image.image as AssetImage;
    expect(portrait.hasMotionAsset, isTrue);
    expect(asset.assetName, PilotMotionPortrait.navigatorMotionAssetPath);
    expect(
      find.byKey(const Key('pilot-motion-frame-navigator-v1-0-0')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Пилот Навигатор'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 140));
    expect(
      find.byKey(const Key('pilot-motion-frame-navigator-v1-0-1')),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    semantics.dispose();
  });

  testWidgets('keeps the first pilot frame when reduced motion is enabled', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: PilotMotionPortrait(
            pilotId: PilotMotionPortrait.navigatorPilotId,
            name: 'Навигатор',
            loop: true,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    expect(
      find.byKey(const Key('pilot-motion-frame-navigator-v1-0-0')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders a selected pilot look direction without playback', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PilotMotionPortrait(
          pilotId: PilotMotionPortrait.navigatorPilotId,
          name: 'Навигатор',
          lookDirection: PilotLookDirection.west,
          loop: true,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.byKey(const Key('pilot-motion-frame-navigator-v1-10-4')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the illustrated fallback for unknown pilot identities', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PilotMotionPortrait(
          pilotId: 'future-pilot-v2',
          name: 'Новый пилот',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final PilotMotionPortrait portrait = tester.widget<PilotMotionPortrait>(
      find.byType(PilotMotionPortrait),
    );
    expect(portrait.hasMotionAsset, isFalse);
    expect(find.byType(PilotPortrait), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the scarf portrait until its own motion art exists', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PilotMotionPortrait(
          pilotId: PilotMotionPortrait.navigatorPilotId,
          name: 'Навигатор',
          equippedCosmeticIds: <String>{CharacterCosmeticIds.pilotScarf},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final PilotMotionPortrait portrait = tester.widget<PilotMotionPortrait>(
      find.byType(PilotMotionPortrait),
    );
    final PilotPortrait fallback = tester.widget<PilotPortrait>(
      find.byType(PilotPortrait),
    );
    expect(portrait.hasMotionAsset, isFalse);
    expect(fallback.hasNavigatorScarf, isTrue);
    expect(fallback.illustrationAsset, PilotPortrait.scarfAssetPath);
    expect(tester.takeException(), isNull);
  });
}
