import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/app/main_navigation_shell.dart';

void main() {
  testWidgets('switches between expedition and platform journal', (
    WidgetTester tester,
  ) async {
    int? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: MainNavigationShell(
          home: const Center(child: Text('home-content')),
          platform: const Center(child: Text('platform-content')),
          onDestinationChanged: (int index) {
            selected = index;
          },
        ),
      ),
    );

    expect(find.text('home-content'), findsOneWidget);
    expect(find.text('platform-content', skipOffstage: false), findsOneWidget);
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 0);

    await tester.tap(find.byKey(const Key('navigation-platform')));
    await tester.pumpAndSettle();

    expect(selected, 1);
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 1);

    await tester.tap(find.byKey(const Key('navigation-home')));
    await tester.pumpAndSettle();

    expect(selected, 0);
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 0);
  });
}
