import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/design_system/companion_portrait.dart';
import 'package:walking_rpg_mobile/design_system/expedition_crew_scene.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

void main() {
  testWidgets('accepted IDs select the matching scene, including after a switch', (
    tester,
  ) async {
    for (final String id in <String>['spark-v1', 'moss-v1', 'rune-v1']) {
      await tester.pumpWidget(_scene(petId: id));
      await tester.pumpAndSettle();
      final ExpeditionCrewScene scene = tester.widget(find.byType(ExpeditionCrewScene));
      final String identity = id.split('-').first;
      expect(scene.sceneAsset, 'assets/scenes/home_crew_${identity}_v2.webp');
      final Image image = tester.widget(find.byType(Image));
      expect((image.image as AssetImage).assetName, scene.sceneAsset);
      expect(image.gaplessPlayback, isFalse);
      expect(find.byKey(const Key('home-active-companion-portrait')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('unknown companion keeps its neutral fallback and no baked-in pet', (
    tester,
  ) async {
    await tester.pumpWidget(_scene(petId: 'future-pet'));
    await tester.pumpAndSettle();
    final ExpeditionCrewScene scene = tester.widget(find.byType(ExpeditionCrewScene));
    expect(scene.sceneAsset, 'assets/scenes/home_pilot_v2.webp');
    final CompanionPortrait fallback = tester.widget(find.byType(CompanionPortrait));
    expect(fallback.petId, 'future-pet');
    expect(fallback.identity, CompanionIdentity.unknown);
    expect(tester.takeException(), isNull);
  });

  testWidgets('incomplete identity never selects artwork from a display name', (
    tester,
  ) async {
    await tester.pumpWidget(_scene(petId: null));
    await tester.pumpAndSettle();
    final ExpeditionCrewScene scene = tester.widget(find.byType(ExpeditionCrewScene));
    expect(scene.sceneAsset, 'assets/scenes/home_pilot_v2.webp');
    expect(find.byKey(const Key('home-active-companion-portrait')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unknown pilot does not inherit the Navigator illustration', (
    tester,
  ) async {
    await tester.pumpWidget(_scene(pilotId: 'future-pilot', petId: null));
    await tester.pumpAndSettle();
    final ExpeditionCrewScene scene = tester.widget(find.byType(ExpeditionCrewScene));
    expect(scene.sceneAsset, 'assets/events/signal_source.webp');
    expect(find.byKey(const Key('home-pilot-illustration')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('full square artwork stays visible on short and wide surfaces', (
    tester,
  ) async {
    for (final double height in <double>[148, 220, 330]) {
      await tester.pumpWidget(_scene(height: height));
      await tester.pumpAndSettle();
      final Rect art = tester.getRect(find.byType(Image));
      expect(art.width, art.height);
      expect(art.height, lessThanOrEqualTo(height));
      for (final String key in <String>[
        'home-pilot-illustration',
        'home-active-companion-portrait',
      ]) {
        final Rect actor = tester.getRect(find.byKey(Key(key)));
        expect(art.contains(actor.topLeft), isTrue);
        expect(art.contains(actor.bottomRight), isTrue);
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('detailed art is static with either motion preference', (
    tester,
  ) async {
    for (final bool reduced in <bool>[false, true]) {
      await tester.pumpWidget(_scene(reduceMotion: reduced));
      await tester.pumpAndSettle();
      expect(find.byType(IconButton), findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pump(const Duration(seconds: 5));
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
    }
  });
}

Widget _scene({
  bool reduceMotion = false,
  String? petId = 'spark-v1',
  String? pilotId = 'navigator-v1',
  double height = 330,
}) => MaterialApp(
  theme: WalkingRpgTheme.dark(),
  home: MediaQuery(
    data: MediaQueryData(
      disableAnimations: reduceMotion,
      size: const Size(390, 844),
    ),
    child: Scaffold(
      body: SingleChildScrollView(
        child: ExpeditionCrewScene(
          semanticLabel: 'Сигнал из туманного сектора',
          pilotId: pilotId,
          pilotName: 'Навигатор',
          height: height,
          petId: petId,
          // Deliberately keep the same name for all IDs: names must not select art.
          petName: 'Искра',
          petSpecies: 'люмин',
          petEvolutionStage: 0,
        ),
      ),
    ),
  ),
);
