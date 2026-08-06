import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/design_system/expedition_progress_signal.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

void main() {
  test('selects a route contour only from the exact expedition ID', () {
    expect(
      ExpeditionProgressSignalCatalog.kindFor('starter-expedition-v1'),
      ExpeditionProgressSignalKind.outerBeacon,
    );
    expect(
      ExpeditionProgressSignalCatalog.kindFor('Сигнал из туманного сектора'),
      ExpeditionProgressSignalKind.unknown,
    );
    expect(
      ExpeditionProgressSignalCatalog.kindFor('starter-expedition-v1-preview'),
      ExpeditionProgressSignalKind.unknown,
    );
    expect(
      ExpeditionProgressSignalCatalog.kindFor('future-expedition-v2'),
      ExpeditionProgressSignalKind.unknown,
    );
  });

  testWidgets('known and future route progress paints at bounded size', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 240));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Future<void> pump(ThemeData theme) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const SizedBox(
                    width: 280,
                    child: ExpeditionProgressSignal(
                      expeditionId: 'starter-expedition-v1',
                      progress: 15,
                      target: 30,
                      height: 76,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const SizedBox(
                    width: 280,
                    child: ExpeditionProgressSignal(
                      expeditionId: 'future-expedition-v2',
                      progress: 40,
                      target: 0,
                      height: 76,
                    ),
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
      const Key('expedition-progress-signal-starter-expedition-v1-outerBeacon'),
    );
    final Finder fallback = find.byKey(
      const Key('expedition-progress-signal-future-expedition-v2-unknown'),
    );
    expect(known, findsOneWidget);
    expect(fallback, findsOneWidget);
    expect(tester.getSize(known), const Size(280, 76));
    expect(tester.getSize(fallback), const Size(280, 76));
    for (final Finder signal in <Finder>[known, fallback]) {
      expect(
        find.descendant(of: signal, matching: find.byType(CustomPaint)),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);

    await pump(WalkingRpgTheme.light());
    expect(known, findsOneWidget);
    expect(fallback, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
