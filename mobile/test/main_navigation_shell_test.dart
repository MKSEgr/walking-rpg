import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/app/main_navigation_shell.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

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

  testWidgets('compact navigation keeps the complete floating dock', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final List<int> selections = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        builder: (BuildContext context, Widget? child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          );
        },
        home: MainNavigationShell(
          home: const Center(child: Text('compact-home-content')),
          platform: const Center(child: Text('compact-platform-content')),
          onDestinationChanged: selections.add,
        ),
      ),
    );

    expect(find.byKey(const Key('main-navigation-compact')), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(
      tester
          .getSize(find.byKey(const Key('main-navigation-bottom-dock')))
          .width,
      lessThanOrEqualTo(304),
    );

    await tester.tap(find.byKey(const Key('navigation-platform')));
    await tester.pumpAndSettle();

    expect(selections, <int>[1]);
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide navigation uses one persistent expedition rail', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1180, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final List<int> selections = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        builder: (BuildContext context, Widget? child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          );
        },
        home: MainNavigationShell(
          home: const Center(child: Text('wide-home-content')),
          platform: const Center(child: Text('wide-platform-content')),
          onDestinationChanged: selections.add,
        ),
      ),
    );

    expect(find.byKey(const Key('main-navigation-wide')), findsOneWidget);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('ПОЛЕВОЙ ТЕРМИНАЛ'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('main-navigation-rail'))).width,
      224,
    );

    await tester.tap(find.byKey(const Key('navigation-platform-wide')));
    await tester.pumpAndSettle();

    expect(selections, <int>[1]);
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
      1,
    );
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 1);

    await tester.tap(find.byKey(const Key('navigation-platform-wide')));
    await tester.pump();
    expect(selections, <int>[1]);

    await tester.tap(find.byKey(const Key('navigation-home-wide')));
    await tester.pumpAndSettle();

    expect(selections, <int>[1, 0]);
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 0);
    expect(tester.takeException(), isNull);
  });
}
