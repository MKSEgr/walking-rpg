import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/design_system/companion_growth.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';
import 'package:walking_rpg_mobile/l10n/generated/app_localizations_en.dart';
import 'package:walking_rpg_mobile/l10n/generated/app_localizations_ru.dart';

void main() {
  test('names the illustrated growth stages without inventing future data', () {
    final AppLocalizationsRu russian = AppLocalizationsRu();
    final AppLocalizationsEn english = AppLocalizationsEn();
    expect(CompanionGrowth.stageName(russian, -1), 'Малыш');
    expect(CompanionGrowth.formLabel(russian, 0), 'Малыш · форма 1');
    expect(CompanionGrowth.formLabel(russian, 1), 'Юный · форма 2');
    expect(CompanionGrowth.formLabel(russian, 2), 'Взрослый · форма 3');
    expect(CompanionGrowth.formLabel(russian, 3), 'Форма 4');
    expect(CompanionGrowth.formLabel(english, 1), 'Young · form 2');
    expect(CompanionGrowth.formLabel(english, 3), 'Form 4');
    expect(CompanionGrowth.illustratedStage(8), 2);
  });

  testWidgets('growth track stays readable with compact enlarged text', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(240, 160));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final SemanticsHandle semantics = tester.ensureSemantics();

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
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 220,
              child: CompanionGrowthTrack(currentStage: 1),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Малыш'), findsOneWidget);
    expect(find.text('Юный'), findsOneWidget);
    expect(find.text('Взрослый'), findsOneWidget);
    expect(find.byKey(const Key('companion-growth-current')), findsOneWidget);
    expect(
      find.bySemanticsLabel('Рост спутника: Юный, этап 2 из 3'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    semantics.dispose();
  });

  testWidgets(
    'future server stage completes known nodes without a fake current',
    (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          theme: WalkingRpgTheme.dark(),
          home: const Scaffold(body: CompanionGrowthTrack(currentStage: 3)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsNWidgets(3));
      expect(find.byKey(const Key('companion-growth-current')), findsNothing);
      expect(
        find.bySemanticsLabel(
          'Рост спутника: Форма 4, показана последняя известная иллюстрация',
        ),
        findsOneWidget,
      );

      semantics.dispose();
    },
  );
}
