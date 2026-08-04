import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/design_system/squad_formation_signal.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

void main() {
  test('compresses only decorative squad nodes', () {
    expect(SquadFormationLayout.visibleMemberCountFor(-1), 0);
    expect(SquadFormationLayout.visibleMemberCountFor(0), 0);
    expect(SquadFormationLayout.visibleMemberCountFor(4), 4);
    expect(SquadFormationLayout.visibleMemberCountFor(9), 6);
    expect(SquadFormationLayout.hasOverflow(6), isFalse);
    expect(SquadFormationLayout.hasOverflow(7), isTrue);
  });

  testWidgets('open and connected formations stay decorative and size-stable', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 240));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final SemanticsHandle semantics = tester.ensureSemantics();

    Future<void> pump(ThemeData theme) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  SquadFormationSignal(
                    connected: false,
                    memberCount: 0,
                    size: 72,
                  ),
                  SizedBox(width: 12),
                  SquadFormationSignal(
                    connected: true,
                    memberCount: 3,
                    size: 72,
                  ),
                  SizedBox(width: 12),
                  SquadFormationSignal(
                    connected: true,
                    memberCount: 9,
                    size: 72,
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

    final Finder open = find.byKey(const Key('squad-formation-signal-open-0'));
    final Finder connected = find.byKey(
      const Key('squad-formation-signal-connected-3'),
    );
    final Finder overflow = find.byKey(
      const Key('squad-formation-signal-connected-6-overflow'),
    );
    expect(open, findsOneWidget);
    expect(connected, findsOneWidget);
    expect(overflow, findsOneWidget);
    expect(tester.getSize(open), const Size.square(72));
    expect(tester.getSize(connected), const Size.square(72));
    expect(tester.getSize(overflow), const Size.square(72));
    expect(find.byType(CustomPaint), findsNWidgets(3));
    expect(find.bySemanticsLabel(RegExp('отряд|участник')), findsNothing);
    expect(tester.takeException(), isNull);

    await pump(WalkingRpgTheme.light());
    expect(open, findsOneWidget);
    expect(connected, findsOneWidget);
    expect(overflow, findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
