import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/design_system/character_cosmetics.dart';
import 'package:walking_rpg_mobile/design_system/companion_portrait.dart';
import 'package:walking_rpg_mobile/design_system/illustrated_portrait.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

void main() {
  testWidgets('renders distinct accessible portraits for all starter pets', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();

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
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      tester
          .widget<CompanionPortrait>(find.byKey(const Key('portrait-spark')))
          .identity,
      CompanionIdentity.spark,
    );
    expect(
      tester
          .widget<CompanionPortrait>(find.byKey(const Key('portrait-moss')))
          .identity,
      CompanionIdentity.moss,
    );
    expect(
      tester
          .widget<CompanionPortrait>(find.byKey(const Key('portrait-rune')))
          .identity,
      CompanionIdentity.rune,
    );
    expect(
      tester
          .widget<CompanionPortrait>(find.byKey(const Key('portrait-spark')))
          .illustrationAsset,
      'assets/characters/companion_spark_stage0.webp',
    );
    expect(
      tester
          .widget<CompanionPortrait>(find.byKey(const Key('portrait-moss')))
          .illustrationAsset,
      'assets/characters/companion_moss_stage1.webp',
    );
    expect(
      tester
          .widget<CompanionPortrait>(find.byKey(const Key('portrait-rune')))
          .illustrationAsset,
      'assets/characters/companion_rune.webp',
    );
    expect(
      find.byKey(const Key('companion-illustration-spark-v1-stage-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('companion-illustration-moss-v1-stage-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('companion-illustration-rune-v1-stage-2')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Искра, люмин, форма 1, активный спутник'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Мох, терра, форма 2'), findsOneWidget);
    expect(find.bySemanticsLabel('Руна, эхо, форма 3'), findsOneWidget);
    semantics.dispose();
  });

  test('maps all three authoritative stages without changing pet identity', () {
    const Map<String, List<String>> expected = <String, List<String>>{
      'spark-v1': <String>[
        'assets/characters/companion_spark_stage0.webp',
        'assets/characters/companion_spark_stage1.webp',
        'assets/characters/companion_spark.webp',
      ],
      'moss-v1': <String>[
        'assets/characters/companion_moss_stage0.webp',
        'assets/characters/companion_moss_stage1.webp',
        'assets/characters/companion_moss.webp',
      ],
      'rune-v1': <String>[
        'assets/characters/companion_rune_stage0.webp',
        'assets/characters/companion_rune_stage1.webp',
        'assets/characters/companion_rune.webp',
      ],
    };

    for (final MapEntry<String, List<String>> entry in expected.entries) {
      for (int stage = 0; stage < entry.value.length; stage += 1) {
        final CompanionPortrait portrait = CompanionPortrait(
          petId: entry.key,
          name: 'Спутник',
          species: 'вид',
          evolutionStage: stage,
        );
        expect(portrait.illustrationAsset, entry.value[stage]);
      }
    }
  });

  testWidgets('renders the equipped Spark halo above the current stage', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        home: const CompanionPortrait(
          petId: 'spark-v1',
          name: 'Искра',
          species: 'люмин',
          evolutionStage: 1,
          equippedCosmeticIds: <String>{CharacterCosmeticIds.sparkHalo},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final CompanionPortrait portrait = tester.widget<CompanionPortrait>(
      find.byType(CompanionPortrait),
    );
    final ExpeditionIllustratedPortrait illustration = tester
        .widget<ExpeditionIllustratedPortrait>(
          find.byType(ExpeditionIllustratedPortrait),
        );
    expect(portrait.hasSparkHalo, isTrue);
    expect(illustration.haloColor, isNotNull);
    expect(
      find.bySemanticsLabel('Искра, люмин, форма 2, Ореол Искры'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    semantics.dispose();
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

    final CompanionPortrait portrait = tester.widget<CompanionPortrait>(
      find.byType(CompanionPortrait),
    );
    expect(portrait.identity, CompanionIdentity.unknown);
    expect(portrait.illustrationAsset, isNull);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
