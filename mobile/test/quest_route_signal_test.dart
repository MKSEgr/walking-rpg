import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/design_system/quest_route_signal.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

void main() {
  test('selects quest marks only from exact server metrics', () {
    expect(
      QuestRouteSignalCatalog.kindFor('TOTAL_ACCEPTED_STEPS'),
      QuestRouteSignalKind.steps,
    );
    expect(
      QuestRouteSignalCatalog.kindFor('RESOLVED_EVENTS'),
      QuestRouteSignalKind.events,
    );
    expect(
      QuestRouteSignalCatalog.kindFor('SQUAD_MEMBERSHIP'),
      QuestRouteSignalKind.squad,
    );
    expect(
      QuestRouteSignalCatalog.kindFor('Первый маршрут'),
      QuestRouteSignalKind.unknown,
    );
    expect(
      QuestRouteSignalCatalog.kindFor('FUTURE_METRIC'),
      QuestRouteSignalKind.unknown,
    );
  });

  testWidgets('known and fallback routes stay size-stable and accessible', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 360));
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      QuestRouteSignal(
                        questId: 'walk-3000',
                        metric: 'TOTAL_ACCEPTED_STEPS',
                        ready: true,
                        claimed: false,
                        size: 56,
                      ),
                      SizedBox(width: 12),
                      QuestRouteSignal(
                        questId: 'resolve-3',
                        metric: 'RESOLVED_EVENTS',
                        ready: false,
                        claimed: false,
                        size: 56,
                      ),
                      SizedBox(width: 12),
                      QuestRouteSignal(
                        questId: 'join-squad',
                        metric: 'SQUAD_MEMBERSHIP',
                        ready: false,
                        claimed: false,
                        size: 56,
                      ),
                      SizedBox(width: 12),
                      QuestRouteSignal(
                        questId: 'future-quest',
                        metric: 'FUTURE_METRIC',
                        ready: true,
                        claimed: true,
                        size: 56,
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  QuestRouteProgress(
                    questId: 'resolve-3',
                    questName: 'Исследователь',
                    metric: 'RESOLVED_EVENTS',
                    progress: 2,
                    target: 3,
                    ready: false,
                    claimed: false,
                  ),
                  SizedBox(height: 16),
                  QuestRouteProgress(
                    questId: 'future-quest',
                    questName: 'Новый маршрут',
                    metric: 'FUTURE_METRIC',
                    progress: 12,
                    target: 10,
                    ready: true,
                    claimed: true,
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
      const Key('quest-route-signal-walk-3000-steps'),
    );
    final Finder fallback = find.byKey(
      const Key('quest-route-signal-future-quest-unknown'),
    );
    expect(known, findsOneWidget);
    expect(fallback, findsOneWidget);
    expect(
      find.byKey(const Key('quest-route-signal-resolve-3-events')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('quest-route-signal-join-squad-squad')),
      findsOneWidget,
    );
    expect(tester.getSize(known), const Size.square(56));
    expect(tester.getSize(fallback), const Size.square(56));
    expect(
      find.descendant(of: known, matching: find.byType(CustomPaint)),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Прогресс задания «Исследователь»: 2 из 3'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Прогресс задания «Новый маршрут»: 12 из 10'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await pump(WalkingRpgTheme.light());
    expect(known, findsOneWidget);
    expect(fallback, findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
