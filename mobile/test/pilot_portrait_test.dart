import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/design_system/pilot_portrait.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

void main() {
  testWidgets('renders the accessible Navigator production portrait', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        home: const Scaffold(
          body: PilotPortrait(
            name: 'Навигатор',
            size: 80,
            highlighted: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Пилот Навигатор'), findsOneWidget);
    final Image image = tester.widget<Image>(
      find.byKey(const Key('pilot-portrait-image')),
    );
    expect(image.image, isA<AssetImage>());
    expect(
      (image.image as AssetImage).assetName,
      PilotPortrait.assetPath,
    );
    expect(tester.takeException(), isNull);

    semantics.dispose();
  });
}
