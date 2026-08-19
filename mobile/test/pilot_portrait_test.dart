import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/design_system/character_cosmetics.dart';
import 'package:walking_rpg_mobile/design_system/pilot_portrait.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';
import 'package:walking_rpg_mobile/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('renders the accessible Navigator production portrait', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        home: const Scaffold(
          body: PilotPortrait(name: 'Навигатор', size: 80, highlighted: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Пилот Навигатор'), findsOneWidget);
    final Image image = tester.widget<Image>(
      find.byKey(const Key('pilot-portrait-image')),
    );
    expect(image.image, isA<AssetImage>());
    expect((image.image as AssetImage).assetName, PilotPortrait.assetPath);
    expect(tester.takeException(), isNull);

    semantics.dispose();
  });

  testWidgets('uses the illustrated Navigator scarf when it is equipped', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: WalkingRpgTheme.dark(),
        home: const Scaffold(
          body: PilotPortrait(
            name: 'Navigator',
            equippedCosmeticIds: <String>{CharacterCosmeticIds.pilotScarf},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final PilotPortrait portrait = tester.widget<PilotPortrait>(
      find.byType(PilotPortrait),
    );
    final Image image = tester.widget<Image>(
      find.byKey(const Key('pilot-portrait-image')),
    );
    expect(portrait.hasNavigatorScarf, isTrue);
    expect(portrait.illustrationAsset, PilotPortrait.scarfAssetPath);
    expect((image.image as AssetImage).assetName, PilotPortrait.scarfAssetPath);
    expect(
      find.bySemanticsLabel('Pilot Navigator, Navigator Scarf'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    semantics.dispose();
  });
}
