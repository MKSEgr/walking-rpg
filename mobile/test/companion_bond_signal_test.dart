import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/design_system/companion_bond_signal.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

void main() {
  test('selects bond identity only from an exact server pet ID', () {
    expect(
      CompanionBondSignalCatalog.identityFor('spark-v1'),
      CompanionBondIdentity.spark,
    );
    expect(
      CompanionBondSignalCatalog.identityFor('moss-v1'),
      CompanionBondIdentity.moss,
    );
    expect(
      CompanionBondSignalCatalog.identityFor('rune-v1'),
      CompanionBondIdentity.rune,
    );
    expect(
      CompanionBondSignalCatalog.identityFor('Искра'),
      CompanionBondIdentity.unknown,
    );
    expect(
      CompanionBondSignalCatalog.identityFor('spark-v1-preview'),
      CompanionBondIdentity.unknown,
    );
    expect(
      CompanionBondSignalCatalog.identityFor('future-pet'),
      CompanionBondIdentity.unknown,
    );
  });

  test('keeps readiness and evolved state owned by the caller', () {
    const CompanionBondSignal growing = CompanionBondSignal(
      petId: 'future-pet',
      petName: 'Тень',
      bond: 60,
      evolutionBond: 45,
      canEvolve: false,
      fullyEvolved: false,
    );
    const CompanionBondSignal ready = CompanionBondSignal(
      petId: 'future-pet',
      petName: 'Тень',
      bond: 12,
      evolutionBond: 45,
      canEvolve: true,
      fullyEvolved: false,
    );
    const CompanionBondSignal evolved = CompanionBondSignal(
      petId: 'future-pet',
      petName: 'Тень',
      bond: 0,
      evolutionBond: 45,
      canEvolve: false,
      fullyEvolved: true,
    );

    expect(growing.status, CompanionBondStatus.growing);
    expect(ready.status, CompanionBondStatus.ready);
    expect(evolved.status, CompanionBondStatus.evolved);
  });

  testWidgets('ready and future bond fields keep literal compact semantics', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(280, 210));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final SemanticsHandle semantics = tester.ensureSemantics();

    Future<void> pump(ThemeData theme) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          builder: (BuildContext context, Widget? child) {
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.6)),
              child: child!,
            );
          },
          home: const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(12),
              child: Column(
                children: <Widget>[
                  CompanionBondSignal(
                    petId: 'spark-v1',
                    petName: 'Искра',
                    bond: 50,
                    evolutionBond: 50,
                    canEvolve: true,
                    fullyEvolved: false,
                  ),
                  SizedBox(height: 12),
                  CompanionBondSignal(
                    petId: 'future-pet',
                    petName: 'Тень',
                    bond: 12,
                    evolutionBond: 45,
                    canEvolve: false,
                    fullyEvolved: false,
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

    final Finder ready = find.byKey(
      const Key('companion-bond-signal-spark-v1-spark-ready'),
    );
    final Finder fallback = find.byKey(
      const Key('companion-bond-signal-future-pet-unknown-growing'),
    );
    expect(ready, findsOneWidget);
    expect(fallback, findsOneWidget);
    expect(find.text('50/50'), findsOneWidget);
    expect(find.text('12/45'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Связь спутника «Искра»: 50 из 50. '
        'Готова к эволюции',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Связь спутника «Тень»: 12 из 45'),
      findsOneWidget,
    );
    for (final Finder field in <Finder>[
      find.byKey(const Key('companion-bond-field-spark-v1-spark-ready')),
      find.byKey(const Key('companion-bond-field-future-pet-unknown-growing')),
    ]) {
      expect(field, findsOneWidget);
      expect(tester.getSize(field).height, 52);
      expect(
        find.descendant(of: field, matching: find.byType(CustomPaint)),
        findsOneWidget,
      );
    }
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);

    await pump(WalkingRpgTheme.light());
    expect(ready, findsOneWidget);
    expect(fallback, findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('evolved bond keeps the accepted literal without a fake target', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        home: const Scaffold(
          body: CompanionBondSignal(
            petId: 'rune-v1',
            petName: 'Навигатор',
            bond: 7,
            evolutionBond: 55,
            canEvolve: false,
            fullyEvolved: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('companion-bond-signal-rune-v1-rune-evolved')),
      findsOneWidget,
    );
    expect(find.text('7'), findsOneWidget);
    expect(find.text('7/55'), findsNothing);
    expect(
      find.bySemanticsLabel('Связь спутника «Навигатор»: 7'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
