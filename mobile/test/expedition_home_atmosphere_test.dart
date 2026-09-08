import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/app/main_navigation_shell.dart';
import 'package:walking_rpg_mobile/design_system/expedition_home_atmosphere.dart';

void main() {
  testWidgets('entrance animation settles and stops scheduling frames', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_testApp(const ExpeditionHomeAtmosphere()));
    expect(_painter(tester).progress, 0);

    await tester.pump(const Duration(milliseconds: 600));
    expect(_painter(tester).progress, greaterThan(0));
    expect(_painter(tester).progress, lessThan(1));

    await tester.pumpAndSettle();
    expect(_painter(tester).progress, 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('reduced motion starts on the final still frame', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        const ExpeditionHomeAtmosphere(),
        disableAnimations: true,
      ),
    );

    expect(_painter(tester).progress, 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pump(const Duration(seconds: 2));
    expect(_painter(tester).progress, 1);
  });

  testWidgets('enabling reduced motion settles without replaying later', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_testApp(const ExpeditionHomeAtmosphere()));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      _painter(tester).progress,
      allOf(greaterThan(0), lessThan(1)),
    );

    await tester.pumpWidget(
      _testApp(
        const ExpeditionHomeAtmosphere(),
        disableAnimations: true,
      ),
    );
    expect(_painter(tester).progress, 1);
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.pumpWidget(_testApp(const ExpeditionHomeAtmosphere()));
    await tester.pump(const Duration(milliseconds: 400));
    expect(_painter(tester).progress, 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('atmosphere is non-interactive and excluded from semantics', (
    WidgetTester tester,
  ) async {
    int taps = 0;
    await tester.pumpWidget(
      _testApp(
        Stack(
          fit: StackFit.expand,
          children: <Widget>[
            FilledButton(
              key: const Key('under-atmosphere-action'),
              onPressed: () {
                taps += 1;
              },
              child: const Text('Continue'),
            ),
            const ExpeditionHomeAtmosphere(),
          ],
        ),
        disableAnimations: true,
      ),
    );

    final IgnorePointer pointer = tester.widget<IgnorePointer>(
      find.byKey(const Key('home-expedition-atmosphere')),
    );
    final ExcludeSemantics semantics = tester.widget<ExcludeSemantics>(
      find.descendant(
        of: find.byKey(const Key('home-expedition-atmosphere')),
        matching: find.byType(ExcludeSemantics),
      ),
    );
    expect(pointer.ignoring, isTrue);
    expect(semantics.excluding, isTrue);
    await tester.tap(find.byKey(const Key('under-atmosphere-action')));
    expect(taps, 1);
  });

  testWidgets('ticker mode pauses and resumes the finite reveal', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        const TickerMode(
          enabled: false,
          child: ExpeditionHomeAtmosphere(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));
    expect(_painter(tester).progress, 0);

    await tester.pumpWidget(
      _testApp(
        const TickerMode(
          enabled: true,
          child: ExpeditionHomeAtmosphere(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(_painter(tester).progress, greaterThan(0));
    expect(_painter(tester).progress, lessThan(1));
    await tester.pumpAndSettle();
    expect(_painter(tester).progress, 1);
  });

  testWidgets('ticker mode can pause a reveal already in progress', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        const TickerMode(
          enabled: true,
          child: ExpeditionHomeAtmosphere(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    final double beforePause = _painter(tester).progress;
    expect(beforePause, allOf(greaterThan(0), lessThan(1)));

    await tester.pumpWidget(
      _testApp(
        const TickerMode(
          enabled: false,
          child: ExpeditionHomeAtmosphere(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));
    expect(_painter(tester).progress, beforePause);
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.pumpWidget(
      _testApp(
        const TickerMode(
          enabled: true,
          child: ExpeditionHomeAtmosphere(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_painter(tester).progress, 1);
  });

  testWidgets('hidden navigation destination pauses and resumes the reveal', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MainNavigationShell(
          home: ExpeditionHomeAtmosphere(),
          crew: ColoredBox(color: Colors.black),
          platform: ColoredBox(color: Colors.black),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    final double beforeHide = _painter(tester).progress;
    expect(beforeHide, greaterThan(0));

    await tester.tap(find.byKey(const Key('navigation-crew')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(_painter(tester).progress, beforeHide);
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.tap(find.byKey(const Key('navigation-home')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(_painter(tester).progress, greaterThan(beforeHide));
    await tester.pumpAndSettle();
    expect(_painter(tester).progress, 1);
  });

  testWidgets('app lifecycle pauses and resumes the finite reveal', (
    WidgetTester tester,
  ) async {
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );
    await tester.pumpWidget(_testApp(const ExpeditionHomeAtmosphere()));
    await tester.pump(const Duration(milliseconds: 400));
    final double beforePause = _painter(tester).progress;
    expect(beforePause, greaterThan(0));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(_painter(tester).progress, beforePause);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(_painter(tester).progress, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing mid-reveal leaves no active ticker', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_testApp(const ExpeditionHomeAtmosphere()));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpWidget(_testApp(const SizedBox()));

    expect(tester.takeException(), isNull);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}

Widget _testApp(Widget child, {bool disableAnimations = false}) => MaterialApp(
  builder: (BuildContext context, Widget? builtChild) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(disableAnimations: disableAnimations),
    child: builtChild!,
  ),
  home: Scaffold(body: child),
);

ExpeditionHomeAtmospherePainter _painter(WidgetTester tester) {
  final CustomPaint paint = tester.widget<CustomPaint>(
    find.byKey(
      const Key('home-expedition-atmosphere-paint'),
      skipOffstage: false,
    ),
  );
  return paint.painter! as ExpeditionHomeAtmospherePainter;
}
