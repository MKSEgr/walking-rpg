import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/design_system/profile_cosmetic_art.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

void main() {
  for (final (String name, ThemeData theme) in <(String, ThemeData)>[
    ('light', WalkingRpgTheme.light()),
    ('dark', WalkingRpgTheme.dark()),
  ]) {
    testWidgets('profile cosmetics keep distinct exact-ID art in $name theme', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                const ProfileCosmeticFrame(
                  cosmeticId: ProfileCosmeticIds.trailBanner,
                  child: const SizedBox(
                    height: 120,
                    child: ColoredBox(color: Colors.transparent),
                  ),
                ),
                const SizedBox(height: 12),
                const ProfileCosmeticFrame(
                  cosmeticId: ProfileCosmeticIds.dawnFrame,
                  child: const SizedBox(
                    height: 120,
                    child: ColoredBox(color: Colors.transparent),
                  ),
                ),
                const SizedBox(height: 12),
                const Row(
                  children: <Widget>[
                    ProfileCosmeticPreview(
                      cosmeticId: ProfileCosmeticIds.trailBanner,
                    ),
                    SizedBox(width: 12),
                    ProfileCosmeticPreview(
                      cosmeticId: ProfileCosmeticIds.dawnFrame,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('profile-cosmetic-frame-trail-banner')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('profile-cosmetic-frame-dawn-frame')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('profile-cosmetic-preview-trail-banner')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('profile-cosmetic-preview-dawn-frame')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'unknown profile cosmetic keeps neutral fallback and child semantics',
    (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          theme: WalkingRpgTheme.dark(),
          home: Scaffold(
            body: Column(
              children: <Widget>[
                ProfileCosmeticFrame(
                  cosmeticId: 'future-profile-style',
                  child: Semantics(
                    image: true,
                    label: 'Принятая сервером глава',
                    child: const SizedBox(width: 240, height: 120),
                  ),
                ),
                const ProfileCosmeticPreview(
                  cosmeticId: 'future-profile-style',
                ),
              ],
            ),
          ),
        ),
      );

      expect(
        find.byKey(
          const Key('profile-cosmetic-frame-fallback-future-profile-style'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key('profile-cosmetic-preview-fallback-future-profile-style'),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Принятая сервером глава'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
}
