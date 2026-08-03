import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/app/main_navigation_shell.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';
import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';
import 'package:walking_rpg_mobile/features/home/presentation/home_screen.dart';
import 'package:walking_rpg_mobile/features/platform/presentation/platform_screen.dart';

import 'support/platform_fixture.dart';

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

    expect(find.byKey(const Key('main-navigation-shell')), findsOneWidget);
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

    expect(find.byKey(const Key('main-navigation-shell')), findsOneWidget);
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

  testWidgets('wide viewport waits for enough height before showing rail', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(960, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
        home: const MainNavigationShell(
          home: Center(child: Text('short-wide-home-content')),
          platform: Center(child: Text('short-wide-platform-content')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      find.byKey(const Key('main-navigation-bottom-dock')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.binding.setSurfaceSize(const Size(960, 480));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps destination state while crossing the breakpoint', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final List<int> selections = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        home: MainNavigationShell(
          home: const Padding(
            padding: EdgeInsets.all(24),
            child: TextField(
              key: Key('navigation-destination-draft'),
              decoration: InputDecoration(labelText: 'Полевая заметка'),
            ),
          ),
          platform: const Center(child: Text('stateful-platform-content')),
          onDestinationChanged: selections.add,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('navigation-destination-draft')),
      'Несохранённая заметка',
    );
    await tester.pump();
    final Object compactEditableState = tester.state(find.byType(EditableText));

    await tester.binding.setSurfaceSize(const Size(1180, 820));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Несохранённая заметка'), findsOneWidget);
    expect(tester.state(find.byType(EditableText)), same(compactEditableState));
    expect(selections, isEmpty);

    await tester.binding.setSurfaceSize(const Size(800, 700));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Несохранённая заметка'), findsOneWidget);
    expect(tester.state(find.byType(EditableText)), same(compactEditableState));
    expect(selections, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide rail removes compact dock reserves from destinations', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1180, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
          home: HomeScreen(loader: () async => HomeSnapshot.demo),
          platform: PlatformScreen(
            loader: () async => platformSnapshot(),
            homeLoader: () async => HomeSnapshot.demo,
            recordExperimentExposures: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final double viewportBottom = tester
        .getBottomRight(find.byKey(const Key('main-navigation-stack')))
        .dy;
    final double actionBottom = tester
        .getBottomRight(find.byKey(const Key('home-sticky-action-panel')))
        .dy;
    expect(viewportBottom - actionBottom, closeTo(20, 1));

    await tester.tap(find.byKey(const Key('navigation-platform-wide')));
    await tester.pumpAndSettle();

    final Finder journalScrollable = find
        .descendant(
          of: find.byKey(const Key('platform-screen-list')),
          matching: find.byType(Scrollable),
        )
        .first;
    final Finder journalFooter = find.byKey(
      const Key('platform-journal-footer'),
    );
    await tester.scrollUntilVisible(
      journalFooter,
      500,
      scrollable: journalScrollable,
    );
    final ScrollableState scrollable = tester.state<ScrollableState>(
      journalScrollable,
    );
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pumpAndSettle();

    final double footerBottom = tester.getBottomRight(journalFooter).dy;
    expect(viewportBottom - footerBottom, closeTo(46, 1));
    expect(tester.takeException(), isNull);
  });
}
