import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/design_system/first_journey_route_signal.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

void main() {
  test('selects first-journey marks only from exact server step IDs', () {
    expect(
      FirstJourneyRouteSignalCatalog.kindFor('welcome'),
      FirstJourneyRouteSignalKind.welcome,
    );
    expect(
      FirstJourneyRouteSignalCatalog.kindFor('health-permission'),
      FirstJourneyRouteSignalKind.healthPermission,
    );
    expect(
      FirstJourneyRouteSignalCatalog.kindFor('first-sync'),
      FirstJourneyRouteSignalKind.firstSync,
    );
    expect(
      FirstJourneyRouteSignalCatalog.kindFor('pet-selection'),
      FirstJourneyRouteSignalKind.petSelection,
    );
    expect(
      FirstJourneyRouteSignalCatalog.kindFor('first-expedition'),
      FirstJourneyRouteSignalKind.firstExpedition,
    );
    expect(
      FirstJourneyRouteSignalCatalog.kindFor('first-event'),
      FirstJourneyRouteSignalKind.firstEvent,
    );
    expect(
      FirstJourneyRouteSignalCatalog.kindFor('Познакомиться с навигатором'),
      FirstJourneyRouteSignalKind.unknown,
    );
    expect(
      FirstJourneyRouteSignalCatalog.kindFor('first-event-preview'),
      FirstJourneyRouteSignalKind.unknown,
    );
    expect(
      FirstJourneyRouteSignalCatalog.kindFor('future-step'),
      FirstJourneyRouteSignalKind.unknown,
    );
  });

  testWidgets(
    'route keeps accepted ordering and literal completion semantics',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 390));
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
                    FirstJourneyRouteSignal(
                      steps: <String>[
                        'welcome',
                        'health-permission',
                        'first-sync',
                        'pet-selection',
                        'first-expedition',
                        'first-event',
                      ],
                      completedSteps: <String>{
                        'welcome',
                        'pet-selection',
                        'not-in-route',
                      },
                      height: 96,
                    ),
                    SizedBox(height: 12),
                    FirstJourneyRouteSignal(
                      steps: <String>['welcome', 'future-step'],
                      completedSteps: <String>{'future-step'},
                      height: 96,
                    ),
                    SizedBox(height: 12),
                    FirstJourneyRouteSignal(
                      steps: <String>[],
                      completedSteps: <String>{'orphan-step'},
                      height: 96,
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
        const Key('first-journey-route-signal-2-6'),
      );
      final Finder fallback = find.byKey(
        const Key('first-journey-route-signal-1-2'),
      );
      final Finder empty = find.byKey(
        const Key('first-journey-route-signal-empty'),
      );
      expect(known, findsOneWidget);
      expect(fallback, findsOneWidget);
      expect(empty, findsOneWidget);
      for (final Finder signal in <Finder>[known, fallback, empty]) {
        expect(tester.getSize(signal).height, 96);
        expect(
          find.descendant(of: signal, matching: find.byType(CustomPaint)),
          findsOneWidget,
        );
        expect(tester.widget<Semantics>(signal).properties.value, isNull);
      }
      expect(
        find.bySemanticsLabel('Первый путь: завершено 2 из 6 этапов'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Первый путь: завершено 1 из 2 этапов'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Первый путь: этапы пока не опубликованы'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await pump(WalkingRpgTheme.light());
      expect(known, findsOneWidget);
      expect(fallback, findsOneWidget);
      expect(empty, findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
}
