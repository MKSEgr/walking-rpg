import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/design_system/expedition_navigation_glyph.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

void main() {
  testWidgets('destination glyphs stay decorative in both themes', (
    WidgetTester tester,
  ) async {
    Future<void> pump(ThemeData theme) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                ExpeditionNavigationGlyph(
                  key: Key('expedition-glyph-under-test'),
                  destination: ExpeditionNavigationDestination.expedition,
                  selected: true,
                  size: 28,
                ),
                SizedBox(width: 20),
                ExpeditionNavigationGlyph(
                  key: Key('journal-glyph-under-test'),
                  destination: ExpeditionNavigationDestination.journal,
                  selected: false,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
    }

    for (final ThemeData theme in <ThemeData>[
      WalkingRpgTheme.dark(),
      WalkingRpgTheme.light(),
    ]) {
      await pump(theme);
      for (final Key key in <Key>[
        const Key('expedition-glyph-under-test'),
        const Key('journal-glyph-under-test'),
      ]) {
        final Finder glyph = find.byKey(key);
        expect(tester.getSize(glyph), const Size.square(28));
        expect(
          find.descendant(of: glyph, matching: find.byType(CustomPaint)),
          findsOneWidget,
        );
        expect(
          find.descendant(of: glyph, matching: find.byType(ExcludeSemantics)),
          findsOneWidget,
        );
      }
      expect(find.byType(Icon), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
}
