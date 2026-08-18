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
                    decision: ExpeditionRouteTrailDecision(
                      choiceId: 'follow-pulse',
                      choiceTitle: 'Пойти за импульсом',
                      outcomeTitle: 'Найден маяк',
                    ),
                  ),
                  ExpeditionRouteTrailNode(
                    nodeId: 'future-branch-v2',
                    nodeName: 'Неизвестная ветвь',
                    state: 'VISITED',
                    decision: ExpeditionRouteTrailDecision(
                      choiceId: 'keep-course',
                      choiceTitle: 'Удержать курс',
                      outcomeTitle: 'Тропа сохранена',
                    ),
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
      find.byKey(const Key('expedition-route-node-outer-beacon-visited')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('expedition-route-node-future-branch-v2-visited')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('expedition-route-node-lumen-gate-current')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('expedition-route-decision-outer-beacon')),
      findsOneWidget,
    );
    expect(
      find.text('Пойти за импульсом → Найден маяк'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('expedition-route-decision-lumen-gate')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('expedition-route-trail-connector')),
      findsNWidgets(2),
    );
    expect(
      find.bySemanticsLabel(
        'Маршрут похода: открыто узлов — 3. '
        'Последняя точка: Люминовые ворота. '
        'Принятые решения: Внешний маяк: Пойти за импульсом → '
        'Найден маяк; Неизвестная ветвь: Удержать курс → '
        'Тропа сохранена.',
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

  testWidgets('long persisted decision copy stays bounded at large text', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 240));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        builder: (BuildContext context, Widget? child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          );
        },
        home: const Scaffold(
          body: ExpeditionRouteTrail(
            nodes: <ExpeditionRouteTrailNode>[
              ExpeditionRouteTrailNode(
                nodeId: 'long-copy-node',
                nodeName: 'Узел с очень длинным сохранённым названием',
                state: 'COMPLETED',
                decision: ExpeditionRouteTrailDecision(
                  choiceId: 'persisted-choice',
                  choiceTitle: 'Следовать по сохранённому световому коридору',
                  outcomeTitle: 'Маршрут удержан вопреки нестабильному сигналу',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('expedition-route-decision-long-copy-node')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
