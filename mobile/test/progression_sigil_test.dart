import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/design_system/progression_sigil.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

void main() {
  test('selects known marks only from exact server identities', () {
    expect(
      ProgressionSigilCatalog.kindFor('steady-step'),
      ProgressionSigilKind.steadyStep,
    );
    expect(
      ProgressionSigilCatalog.kindFor('signal-reader'),
      ProgressionSigilKind.signalReader,
    );
    expect(
      ProgressionSigilCatalog.kindFor('weekly-route-complete'),
      ProgressionSigilKind.weeklyRoute,
    );
    expect(
      ProgressionSigilCatalog.kindFor('season-level-3'),
      ProgressionSigilKind.seasonThree,
    );
    expect(
      ProgressionSigilCatalog.kindFor('Ровный шаг'),
      ProgressionSigilKind.unknown,
    );
    expect(
      ProgressionSigilCatalog.kindFor('future-skill-v1'),
      ProgressionSigilKind.unknown,
    );
  });

  testWidgets('known and fallback sigils remain decorative and size-stable', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(180, 100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final SemanticsHandle semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        home: const Scaffold(
          body: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              ProgressionSigil(identity: 'steady-step', active: true),
              SizedBox(width: 12),
              ProgressionSigil(identity: 'future-skill-v1', active: false),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder known = find.byKey(
      const Key('progression-sigil-steady-step-active'),
    );
    final Finder fallback = find.byKey(
      const Key('progression-sigil-future-skill-v1-locked'),
    );
    expect(known, findsOneWidget);
    expect(fallback, findsOneWidget);
    expect(tester.getSize(known), const Size.square(56));
    expect(tester.getSize(fallback), const Size.square(56));
    expect(
      find.descendant(of: known, matching: find.byType(CustomPaint)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: fallback, matching: find.byType(CustomPaint)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    semantics.dispose();
  });
}
