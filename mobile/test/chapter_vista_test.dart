import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/design_system/chapter_vista.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

void main() {
  testWidgets('renders authoritative route progress as one image semantic', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        home: const Scaffold(
          body: ChapterVista(
            key: Key('chapter-vista'),
            semanticLabel: 'Внешний маяк',
            progress: 0.625,
          ),
        ),
      ),
    );

    final ChapterVista vista = tester.widget<ChapterVista>(
      find.byKey(const Key('chapter-vista')),
    );
    expect(vista.normalizedProgress, 0.625);
    expect(find.bySemanticsLabel('Внешний маяк, маршрут 63%'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('clamps visual progress and fits a narrow light surface', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.light(),
        home: const Center(
          child: SizedBox(
            width: 180,
            child: ChapterVista(
              key: Key('narrow-chapter-vista'),
              semanticLabel: 'Туманный сектор',
              progress: 3,
              height: 112,
            ),
          ),
        ),
      ),
    );

    final ChapterVista vista = tester.widget<ChapterVista>(
      find.byKey(const Key('narrow-chapter-vista')),
    );
    expect(vista.normalizedProgress, 1);
    expect(tester.takeException(), isNull);
  });
}
