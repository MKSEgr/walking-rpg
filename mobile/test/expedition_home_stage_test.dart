import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/design_system/expedition_home_stage.dart';

void main() {
  testWidgets('short landscape keeps event actions and HUD controls scrollable', (
    WidgetTester tester,
  ) async {
    const Size screenSize = Size(640, 320);
    int eventChoices = 0;
    int eventAcknowledgements = 0;
    int primaryActions = 0;
    await tester.binding.setSurfaceSize(screenSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.viewPadding = const FakeViewPadding(
      left: 30,
      top: 18,
      right: 24,
      bottom: 16,
    );
    tester.view.padding = const FakeViewPadding(
      left: 30,
      top: 18,
      right: 24,
      bottom: 16,
    );
    addTearDown(tester.view.resetViewPadding);
    addTearDown(tester.view.resetPadding);

    await tester.pumpWidget(
      MaterialApp(
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: Scaffold(
          body: ExpeditionHomeStage(
            topInset: 42,
            bottomInset: 86,
            scene: const ColoredBox(color: Colors.blueGrey),
            header: const _TestPanel(
              child: Text('Route status with large text'),
            ),
            footer: _TestPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text('Activity and synchronization status'),
                  const SizedBox(height: 90),
                  FilledButton(
                    key: const Key('test-primary-hud-action'),
                    onPressed: () {
                      primaryActions += 1;
                    },
                    child: const Text('Primary expedition action'),
                  ),
                ],
              ),
            ),
            details: ListView(
              key: const Key('test-details-scroll'),
              padding: EdgeInsets.zero,
              children: <Widget>[
                const SizedBox(height: 260),
                FilledButton(
                  key: const Key('test-event-choice'),
                  onPressed: () {
                    eventChoices += 1;
                  },
                  child: const Text('Choose event option'),
                ),
                const SizedBox(height: 420),
                FilledButton(
                  key: const Key('test-event-result-acknowledge'),
                  onPressed: () {
                    eventAcknowledgements += 1;
                  },
                  child: const Text('Confirm event result'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.byKey(const Key('home-fullscreen-background'))),
      Offset.zero & screenSize,
    );
    final Rect detailsViewport = tester.getRect(
      find.byKey(const Key('test-details-scroll')),
    );
    final Rect hudViewport = tester.getRect(
      find.byKey(const Key('home-landscape-hud-scroll')),
    );
    expect(detailsViewport.height, 192);
    expect(detailsViewport.left, greaterThanOrEqualTo(30));
    expect(hudViewport.left, greaterThan(detailsViewport.right));
    expect(hudViewport.right, lessThanOrEqualTo(screenSize.width - 24));
    expect(detailsViewport.top, greaterThanOrEqualTo(18));
    expect(detailsViewport.bottom, lessThanOrEqualTo(screenSize.height - 16));

    final Finder detailsScrollable = find.descendant(
      of: find.byKey(const Key('test-details-scroll')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('test-event-choice')),
      120,
      scrollable: detailsScrollable,
    );
    // A partially visible child can end the search before its center is in
    // view. Lay out the final ensureVisible jump before hit testing or tapping.
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('test-event-choice')).hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('test-event-choice')));
    await tester.pumpAndSettle();
    expect(eventChoices, 1);
    await tester.scrollUntilVisible(
      find.byKey(const Key('test-event-result-acknowledge')),
      160,
      scrollable: detailsScrollable,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('test-event-result-acknowledge')).hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('test-event-result-acknowledge')));
    await tester.pumpAndSettle();
    expect(eventAcknowledgements, 1);

    final Finder hudScrollable = find.descendant(
      of: find.byKey(const Key('home-landscape-hud-scroll')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('test-primary-hud-action')),
      100,
      scrollable: hudScrollable,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('test-primary-hud-action')).hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('test-primary-hud-action')));
    await tester.pumpAndSettle();
    expect(primaryActions, 1);
    expect(eventChoices, 1);
    expect(eventAcknowledgements, 1);
    expect(tester.takeException(), isNull);
  });
}

class _TestPanel extends StatelessWidget {
  const _TestPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.black87,
    child: Padding(padding: const EdgeInsets.all(12), child: child),
  );
}
