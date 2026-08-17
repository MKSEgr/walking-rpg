import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/design_system/expedition_route_trail.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

void main() {
  testWidgets('renders accepted route order and literal terminal state', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(340, 260));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final SemanticsHandle semantics = tester.ensureSemantics();

    Future<void> pump(ThemeData theme) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: ExpeditionRouteTrail(
                nodes: <ExpeditionRouteTrailNode>[
                  ExpeditionRouteTrailNode(
                    nodeId: 'outer-beacon',
                    nodeName: 'Внешний маяк',
                    state: 'VISITED',
                  ),
                  ExpeditionRouteTrailNode(
                    nodeId: 'future-branch-v2',
                    nodeName: 'Неизвестная ветвь',
                    state: 'VISITED',
                  ),
                  ExpeditionRouteTrailNode(
                    nodeId: 'lumen-gate',
                    nodeName: 'Люминовые ворота',
                    state: 'CURRENT',
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

    expect(
      find.byKey(const Key('expedition-route-trail-3-current')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key('expedition-route-node-outer-beacon-visited'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key('expedition-route-node-future-branch-v2-visited'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('expedition-route-node-lumen-gate-current')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('expedition-route-trail-connector')),
      findsNWidgets(2),
    );
    expect(
      find.bySemanticsLabel(
        'Маршрут похода: открыто узлов — 3. '
        'Последняя точка: Люминовые ворота.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await pump(WalkingRpgTheme.light());
    expect(
      find.byKey(const Key('expedition-route-trail-3-current')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('empty accepted trail stays absent', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ExpeditionRouteTrail(nodes: <ExpeditionRouteTrailNode>[]),
        ),
      ),
    );

    expect(
      find.byKey(const Key('expedition-route-trail-empty')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('expedition-route-trail-scroll')),
      findsNothing,
    );
  });
}
