import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/design_system/expedition_ui.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';
import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';
import 'package:walking_rpg_mobile/features/home/presentation/home_screen.dart';

void main() {
  testWidgets('dark theme exposes semantic game accents', (
    WidgetTester tester,
  ) async {
    late WalkingRpgPalette palette;

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        home: Builder(
          builder: (BuildContext context) {
            palette = context.walkingRpgPalette;
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );

    expect(palette.energy, WalkingRpgColors.energy);
    expect(palette.resonance, WalkingRpgColors.resonance);
    expect(palette.energy, isNot(palette.resonance));
  });

  testWidgets('expedition primitives keep readable semantic content', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.light(),
        home: const Scaffold(
          body: ExpeditionBackdrop(
            child: Center(
              child: ExpeditionPanel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ExpeditionBadge(label: 'Внешний маяк', icon: Icons.radar),
                    ExpeditionProgressRing(
                      progress: 0.42,
                      value: '42%',
                      label: 'шаги',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('ВНЕШНИЙ МАЯК'), findsOneWidget);
    expect(find.text('42%'), findsOneWidget);
    expect(find.text('ШАГИ'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('expedition home renders with the game theme', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        home: HomeScreen(loader: () async => HomeSnapshot.demo),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Walking RPG'), findsOneWidget);
    expect(find.text('Экспедиция ждёт твоих шагов'), findsOneWidget);
    expect(find.text('Сегодня: 0 / 6000'), findsOneWidget);
  });
}
