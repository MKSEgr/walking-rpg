import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/design_system/season_reward_seal.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

void main() {
  test('selects a reward seal only from an exact server season ID', () {
    expect(
      SeasonRewardSealCatalog.identityFor('signal-season-1'),
      SeasonRewardSealIdentity.firstSignal,
    );
    expect(
      SeasonRewardSealCatalog.identityFor('season-1'),
      SeasonRewardSealIdentity.firstSignal,
    );
    expect(
      SeasonRewardSealCatalog.identityFor('Сезон первого сигнала'),
      SeasonRewardSealIdentity.unknown,
    );
    expect(
      SeasonRewardSealCatalog.identityFor('season-1-preview'),
      SeasonRewardSealIdentity.unknown,
    );
    expect(
      SeasonRewardSealCatalog.identityFor('signal-season-1-preview'),
      SeasonRewardSealIdentity.unknown,
    );
    expect(
      SeasonRewardSealCatalog.identityFor('future-season'),
      SeasonRewardSealIdentity.unknown,
    );
  });

  testWidgets('known and future rewards preserve the owning button semantics', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 180));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final SemanticsHandle semantics = tester.ensureSemantics();

    Future<void> pump(ThemeData theme) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Center(
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const SeasonRewardSeal(
                      seasonId: 'signal-season-1',
                      level: 2,
                      totalLevels: 10,
                      size: 32,
                    ),
                    label: const Text('Награда уровня 2'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const SeasonRewardSeal(
                      seasonId: 'future-season',
                      level: 4,
                      totalLevels: 12,
                      size: 32,
                    ),
                    label: const Text('Награда уровня 4'),
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
      const Key('season-reward-seal-signal-season-1-2-firstSignal'),
    );
    final Finder fallback = find.byKey(
      const Key('season-reward-seal-future-season-4-unknown'),
    );
    expect(known, findsOneWidget);
    expect(fallback, findsOneWidget);
    expect(tester.getSize(known), const Size.square(32));
    expect(tester.getSize(fallback), const Size.square(32));
    for (final Finder seal in <Finder>[known, fallback]) {
      expect(
        find.descendant(of: seal, matching: find.byType(CustomPaint)),
        findsOneWidget,
      );
    }
    expect(find.bySemanticsLabel('Награда уровня 2'), findsOneWidget);
    expect(find.bySemanticsLabel('Награда уровня 4'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await pump(WalkingRpgTheme.light());
    expect(known, findsOneWidget);
    expect(fallback, findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
