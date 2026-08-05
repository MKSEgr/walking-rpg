import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/design_system/crafting_assembly_signal.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

void main() {
  test('selects assembly identity only from an exact recipe ID', () {
    expect(
      CraftingAssemblySignalCatalog.kindFor('resonance-compass-v1'),
      CraftingAssemblySignalKind.resonanceCompass,
    );
    expect(
      CraftingAssemblySignalCatalog.kindFor(
        'Резонансный компас',
      ),
      CraftingAssemblySignalKind.unknown,
    );
    expect(
      CraftingAssemblySignalCatalog.kindFor('resonance-compass-v1-preview'),
      CraftingAssemblySignalKind.unknown,
    );
    expect(
      CraftingAssemblySignalCatalog.kindFor('future-recipe'),
      CraftingAssemblySignalKind.unknown,
    );
  });

  test('caps only decorative ingredient nodes', () {
    expect(CraftingAssemblySignalLayout.visibleIngredientCountFor(-1), 0);
    expect(CraftingAssemblySignalLayout.visibleIngredientCountFor(0), 0);
    expect(CraftingAssemblySignalLayout.visibleIngredientCountFor(3), 3);
    expect(CraftingAssemblySignalLayout.visibleIngredientCountFor(8), 4);
    expect(CraftingAssemblySignalLayout.hasOverflow(4), isFalse);
    expect(CraftingAssemblySignalLayout.hasOverflow(5), isTrue);
  });

  testWidgets('known and fallback contours stay decorative in both themes', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 420));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final SemanticsHandle semantics = tester.ensureSemantics();

    Future<void> pump(ThemeData theme) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: <Widget>[
                  CraftingAssemblySignal(
                    recipeId: 'resonance-compass-v1',
                    status: 'READY',
                    ingredientAvailability: <bool>[true, true],
                  ),
                  SizedBox(height: 16),
                  CraftingAssemblySignal(
                    recipeId: 'future-recipe',
                    status: 'MISSING_MATERIALS',
                    ingredientAvailability: <bool>[
                      true,
                      false,
                      false,
                      true,
                      false,
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pump(WalkingRpgTheme.dark());

    final Finder known = find.byKey(
      const Key(
        'crafting-assembly-signal-resonance-compass-v1-'
        'resonanceCompass-READY',
      ),
    );
    final Finder fallback = find.byKey(
      const Key(
        'crafting-assembly-signal-future-recipe-unknown-MISSING_MATERIALS',
      ),
    );
    expect(known, findsOneWidget);
    expect(fallback, findsOneWidget);
    expect(tester.getSize(known).height, 112);
    expect(tester.getSize(fallback).height, 112);
    for (final Finder signal in <Finder>[known, fallback]) {
      expect(
        find.descendant(of: signal, matching: find.byType(CustomPaint)),
        findsOneWidget,
      );
    }
    expect(
      find.bySemanticsLabel(
        RegExp('рецепт|ингредиент|материал'),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);

    await pump(WalkingRpgTheme.light());
    expect(known, findsOneWidget);
    expect(fallback, findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
