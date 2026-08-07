import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/design_system/activity_intake_signal.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

void main() {
  testWidgets('step intake signal stays static and bounded in both themes', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 220));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final SemanticsHandle semantics = tester.ensureSemantics();

    Future<void> pump(ThemeData theme) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: ActivityIntakeSignal(
                  key: Key('activity-intake-signal-under-test'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pump(WalkingRpgTheme.dark());

    final Finder signal = find.byKey(
      const Key('activity-intake-signal-under-test'),
    );
    expect(signal, findsOneWidget);
    expect(tester.getSize(signal), const Size(280, 124));
    expect(
      find.bySemanticsLabel(
        'Сигнал подключения шагов: только количество шагов, '
        'без геолокации',
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: signal, matching: find.byType(CustomPaint)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await pump(WalkingRpgTheme.light());
    expect(signal, findsOneWidget);
    expect(tester.getSize(signal), const Size(280, 124));
    expect(tester.takeException(), isNull);

    semantics.dispose();
  });
}
