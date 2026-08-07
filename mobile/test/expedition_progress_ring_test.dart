import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/design_system/expedition_ui.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

void main() {
  testWidgets('daily route orbit keeps one literal progress summary', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 240));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final SemanticsHandle semantics = tester.ensureSemantics();

    Future<void> pump(ThemeData theme) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          builder: (BuildContext context, Widget? child) {
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.6)),
              child: child!,
            );
          },
          home: const Scaffold(
            body: Center(
              child: ExpeditionProgressRing(
                progress: 0.42,
                value: '42%',
                label: 'шаги',
                size: 108,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pump(WalkingRpgTheme.dark());

    final Finder orbit = find.byType(ExpeditionProgressRing);
    final Finder orbitSemantics = find.descendant(
      of: orbit,
      matching: find.byType(Semantics),
    );
    expect(orbit, findsOneWidget);
    expect(tester.getSize(orbit), const Size.square(108));
    expect(
      find.descendant(of: orbit, matching: find.byType(CustomPaint)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: orbit,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );
    expect(find.bySemanticsLabel('шаги, 42%'), findsOneWidget);
    expect(tester.widget<Semantics>(orbitSemantics).properties.value, '42%');
    expect(tester.takeException(), isNull);

    await pump(WalkingRpgTheme.light());
    expect(orbit, findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('route orbit bounds presentation progress at both edges', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();

    Future<void> pump(double progress, String value) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: WalkingRpgTheme.dark(),
          home: Scaffold(
            body: Center(
              child: ExpeditionProgressRing(
                progress: progress,
                value: value,
                label: 'шаги',
                size: 96,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pump(-0.4, '0%');
    Finder orbit = find.byType(ExpeditionProgressRing);
    Finder orbitSemantics = find.descendant(
      of: orbit,
      matching: find.byType(Semantics),
    );
    expect(tester.widget<Semantics>(orbitSemantics).properties.value, '0%');
    expect(tester.takeException(), isNull);

    await pump(1.4, '100%');
    orbit = find.byType(ExpeditionProgressRing);
    orbitSemantics = find.descendant(
      of: orbit,
      matching: find.byType(Semantics),
    );
    expect(tester.widget<Semantics>(orbitSemantics).properties.value, '100%');
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
