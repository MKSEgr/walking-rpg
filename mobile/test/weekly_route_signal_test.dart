import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';
import 'package:walking_rpg_mobile/design_system/weekly_route_signal.dart';

void main() {
  test('selects the weekly route identity only from an exact server ID', () {
    expect(
      WeeklyRouteSignalCatalog.kindFor('weekly-route-1'),
      WeeklyRouteSignalKind.firstSignal,
    );
    expect(
      WeeklyRouteSignalCatalog.kindFor('Сезон первого сигнала'),
      WeeklyRouteSignalKind.unknown,
    );
    expect(
      WeeklyRouteSignalCatalog.kindFor('weekly-route-1-preview'),
      WeeklyRouteSignalKind.unknown,
    );
    expect(
      WeeklyRouteSignalCatalog.kindFor('future-route'),
      WeeklyRouteSignalKind.unknown,
    );
  });

  testWidgets('known and fallback beacons keep exact progress semantics', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 280));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final SemanticsHandle semantics = tester.ensureSemantics();

    Future<void> pump(ThemeData theme) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 16,
                children: <Widget>[
                  WeeklyRouteSignal(
                    routeId: 'weekly-route-1',
                    seasonName: 'Сезон первого сигнала',
                    progress: 40,
                    target: 100,
                    size: 88,
                  ),
                  WeeklyRouteSignal(
                    routeId: 'future-route',
                    seasonName: 'Новый сезон',
                    progress: 140,
                    target: 100,
                    size: 88,
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
      const Key('weekly-route-signal-weekly-route-1-firstSignal'),
    );
    final Finder fallback = find.byKey(
      const Key('weekly-route-signal-future-route-unknown'),
    );
    final Finder knownBeacon = find.byKey(
      const Key('weekly-route-beacon-weekly-route-1-firstSignal'),
    );
    final Finder fallbackBeacon = find.byKey(
      const Key('weekly-route-beacon-future-route-unknown'),
    );
    expect(known, findsOneWidget);
    expect(fallback, findsOneWidget);
    expect(tester.getSize(knownBeacon), const Size.square(88));
    expect(tester.getSize(fallbackBeacon), const Size.square(88));
    for (final Finder beacon in <Finder>[knownBeacon, fallbackBeacon]) {
      expect(
        find.descendant(of: beacon, matching: find.byType(CustomPaint)),
        findsOneWidget,
      );
    }
    expect(
      find.bySemanticsLabel(
        'Недельный маршрут «Сезон первого сигнала»: 40 из 100 ENERGY',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Недельный маршрут «Новый сезон»: 140 из 100 ENERGY',
      ),
      findsOneWidget,
    );
    expect(find.text('40 / 100 ENERGY'), findsOneWidget);
    expect(find.text('140 / 100 ENERGY'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await pump(WalkingRpgTheme.light());
    expect(known, findsOneWidget);
    expect(fallback, findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
