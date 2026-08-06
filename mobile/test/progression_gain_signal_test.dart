import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/design_system/progression_gain_signal.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

void main() {
  test(
    'catalog selects identities only from an exact channel and subject ID',
    () {
      expect(
        ProgressionGainSignalCatalog.identityFor(
          kind: ProgressionGainKind.pilotExperience,
          subjectId: 'navigator-v1',
        ),
        ProgressionGainIdentity.navigator,
      );
      expect(
        ProgressionGainSignalCatalog.identityFor(
          kind: ProgressionGainKind.petBond,
          subjectId: 'spark-v1',
        ),
        ProgressionGainIdentity.spark,
      );
      expect(
        ProgressionGainSignalCatalog.identityFor(
          kind: ProgressionGainKind.petBond,
          subjectId: 'moss-v1',
        ),
        ProgressionGainIdentity.moss,
      );
      expect(
        ProgressionGainSignalCatalog.identityFor(
          kind: ProgressionGainKind.petBond,
          subjectId: 'rune-v1',
        ),
        ProgressionGainIdentity.rune,
      );
    },
  );

  test('known IDs in another channel and future subjects stay neutral', () {
    for (final ({ProgressionGainKind kind, String subjectId}) entry
        in <({ProgressionGainKind kind, String subjectId})>[
          (kind: ProgressionGainKind.pilotExperience, subjectId: 'spark-v1'),
          (kind: ProgressionGainKind.petBond, subjectId: 'navigator-v1'),
          (
            kind: ProgressionGainKind.pilotExperience,
            subjectId: 'future-pilot-v2',
          ),
          (kind: ProgressionGainKind.petBond, subjectId: 'future-pet-v2'),
        ]) {
      expect(
        ProgressionGainSignalCatalog.identityFor(
          kind: entry.kind,
          subjectId: entry.subjectId,
        ),
        ProgressionGainIdentity.unknown,
      );
      expect(
        ProgressionGainSignalCatalog.toneFor(
          kind: entry.kind,
          subjectId: entry.subjectId,
        ),
        ProgressionGainTone.neutral,
      );
    }
  });

  testWidgets(
    'known and fallback gain marks keep server copy accessible in both themes',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final SemanticsHandle semantics = tester.ensureSemantics();

      for (final ThemeData theme in <ThemeData>[
        WalkingRpgTheme.light(),
        WalkingRpgTheme.dark(),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey<Brightness>(theme.brightness),
            theme: theme,
            builder: (BuildContext context, Widget? child) {
              return MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.6)),
                child: child!,
              );
            },
            home: Scaffold(
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 320,
                    child: ProgressionGainSignalLayout(
                      kind: ProgressionGainKind.pilotExperience,
                      subjectId: 'navigator-v1',
                      child: Semantics(
                        label: 'Пилот получил 40 опыта, всего 60',
                        excludeSemantics: true,
                        child: const Text('+40 XP · всего 60'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 220,
                    child: ProgressionGainSignalLayout(
                      kind: ProgressionGainKind.petBond,
                      subjectId: 'future-pet-v2',
                      child: Semantics(
                        label: 'Спутник получил 5 связи, всего 15',
                        excludeSemantics: true,
                        child: const Text('+5 связи · всего 15'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();

        final Finder known = find.byKey(
          const Key(
            'progression-gain-signal-pilotExperience-navigator-v1-navigator',
          ),
        );
        final Finder fallback = find.byKey(
          const Key('progression-gain-signal-petBond-future-pet-v2-unknown'),
        );
        expect(known, findsOneWidget);
        expect(fallback, findsOneWidget);
        expect(tester.getSize(known), const Size.square(44));
        expect(tester.getSize(fallback), const Size.square(44));
        expect(
          find.byKey(
            const Key(
              'progression-gain-layout-pilotExperience-navigator-v1-wide',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(
            const Key('progression-gain-layout-petBond-future-pet-v2-compact'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(
            const Key('progression-gain-signal-petBond-future-pet-v2-spark'),
          ),
          findsNothing,
        );
        expect(
          find.bySemanticsLabel('Пилот получил 40 опыта, всего 60'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('Спутник получил 5 связи, всего 15'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }

      semantics.dispose();
    },
  );
}
