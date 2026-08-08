import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/design_system/companion_motion.dart';
import 'package:walking_rpg_mobile/design_system/companion_portrait.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

void main() {
  test('maps the approved game clips and look directions to the atlas', () {
    expect(CompanionMotionClip.idle.row, 0);
    expect(CompanionMotionClip.idle.frameCount, 6);
    expect(CompanionMotionClip.runRight.row, 1);
    expect(CompanionMotionClip.runLeft.row, 2);
    expect(CompanionMotionClip.inspect.row, 8);
    expect(CompanionLookDirection.north.row, 9);
    expect(CompanionLookDirection.north.column, 0);
    expect(CompanionLookDirection.south.row, 10);
    expect(CompanionLookDirection.south.column, 0);
    expect(CompanionLookDirection.northNorthWest.column, 7);
    expect(CompanionLookDirection.northNorthWest.degrees, 337.5);
  });

  testWidgets('renders Искра from the game motion atlas', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        home: const Scaffold(
          body: CompanionMotionPortrait(
            key: Key('spark-motion'),
            petId: 'spark-v1',
            name: 'Искра',
            species: 'люмин',
            evolutionStage: 0,
            active: true,
          ),
        ),
      ),
    );
    await tester.pump();

    final CompanionMotionPortrait portrait = tester
        .widget<CompanionMotionPortrait>(find.byKey(const Key('spark-motion')));
    final Image image = tester.widget<Image>(find.byType(Image));
    final AssetImage asset = image.image as AssetImage;
    expect(portrait.hasMotionAsset, isTrue);
    expect(asset.assetName, 'assets/characters/companion_spark_motion_v1.png');
    expect(
      find.byKey(const Key('companion-motion-frame-spark-v1-0-0')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Искра, люмин, Малыш · форма 1, активный спутник'),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 140));
    expect(
      find.byKey(const Key('companion-motion-frame-spark-v1-0-1')),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    semantics.dispose();
  });

  testWidgets('keeps the first frame when reduced motion is enabled', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: CompanionMotionPortrait(
            petId: 'spark-v1',
            name: 'Искра',
            species: 'люмин',
            evolutionStage: 1,
            loop: true,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    expect(
      find.byKey(const Key('companion-motion-frame-spark-v1-0-0')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders a selected look direction without starting a clip', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CompanionMotionPortrait(
          petId: 'spark-v1',
          name: 'Искра',
          species: 'люмин',
          evolutionStage: 1,
          lookDirection: CompanionLookDirection.west,
          loop: true,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.byKey(const Key('companion-motion-frame-spark-v1-10-4')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the existing portrait fallback for other pets', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CompanionMotionPortrait(
          petId: 'moss-v1',
          name: 'Мох',
          species: 'терра',
          evolutionStage: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final CompanionMotionPortrait portrait = tester
        .widget<CompanionMotionPortrait>(find.byType(CompanionMotionPortrait));
    expect(portrait.hasMotionAsset, isFalse);
    expect(find.byType(CompanionPortrait), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
