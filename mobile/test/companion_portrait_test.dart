import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/design_system/companion_portrait.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

void main() {
  testWidgets('renders distinct accessible portraits for all starter pets', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        home: const Scaffold(
          body: Wrap(
            children: <Widget>[
              CompanionPortrait(
                key: Key('portrait-spark'),
                petId: 'spark-v1',
                name: 'Искра',
                species: 'люмин',
                evolutionStage: 0,
                active: true,
              ),
              CompanionPortrait(
                key: Key('portrait-moss'),
                petId: 'moss-v1',
                name: 'Мох',
                species: 'терра',
                evolutionStage: 1,
              ),
              CompanionPortrait(
                key: Key('portrait-rune'),
                petId: 'rune-v1',
                name: 'Руна',
                species: 'эхо',
                evolutionStage: 2,
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.widget<CompanionPortrait>(find.byKey(const Key('portrait-spark')))
          .identity,
      CompanionIdentity.spark,
    );
    expect(
      tester.widget<CompanionPortrait>(find.byKey(const Key('portrait-moss')))
          .identity,
      CompanionIdentity.moss,
    );
    expect(
      tester.widget<CompanionPortrait>(find.byKey(const Key('portrait-rune')))
          .identity,
      CompanionIdentity.rune,
    );
    expect(
      find.bySemanticsLabel(
        'Искра, люмин, форма 1, активный спутник',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Мох, терра, форма 2'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Руна, эхо, форма 3'),
      findsOneWidget,
    );
  });

  testWidgets('uses the fallback identity for future server-owned pets', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.light(),
        home: const CompanionPortrait(
          petId: 'future-pet-v1',
          name: 'Новый спутник',
          species: 'неизвестно',
          evolutionStage: 0,
        ),
      ),
    );

    expect(
      tester.widget<CompanionPortrait>(find.byType(CompanionPortrait)).identity,
      CompanionIdentity.unknown,
    );
    expect(tester.takeException(), isNull);
  });
}
