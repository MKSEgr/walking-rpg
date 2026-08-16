import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/design_system/expedition_node_signal.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

void main() {
  test('selects every current landmark only from an exact node ID', () {
    const Map<String, ExpeditionNodeSignalKind> expected =
        <String, ExpeditionNodeSignalKind>{
          'outer-beacon': ExpeditionNodeSignalKind.outerBeacon,
          'lumen-gate': ExpeditionNodeSignalKind.lumenGate,
          'ash-orbit': ExpeditionNodeSignalKind.ashOrbit,
          'glass-marsh': ExpeditionNodeSignalKind.glassMarsh,
          'silent-quarry': ExpeditionNodeSignalKind.silentQuarry,
          'copper-ravine': ExpeditionNodeSignalKind.copperRavine,
          'ion-garden': ExpeditionNodeSignalKind.ionGarden,
          'frost-antenna': ExpeditionNodeSignalKind.frostAntenna,
          'obsidian-crossing': ExpeditionNodeSignalKind.obsidianCrossing,
          'pulse-foundry': ExpeditionNodeSignalKind.pulseFoundry,
          'mirror-delta': ExpeditionNodeSignalKind.mirrorDelta,
          'storm-archive': ExpeditionNodeSignalKind.stormArchive,
          'ember-station': ExpeditionNodeSignalKind.emberStation,
          'aurora-bridge': ExpeditionNodeSignalKind.auroraBridge,
          'void-orchard': ExpeditionNodeSignalKind.voidOrchard,
          'star-well': ExpeditionNodeSignalKind.starWell,
          'horizon-spire': ExpeditionNodeSignalKind.horizonSpire,
          'dawn-relay': ExpeditionNodeSignalKind.dawnRelay,
          'resonance-pocket': ExpeditionNodeSignalKind.resonancePocket,
          'spectrum-observatory': ExpeditionNodeSignalKind.spectrumObservatory,
          'second-dawn-threshold': ExpeditionNodeSignalKind.secondDawnThreshold,
          'uncharted-verge': ExpeditionNodeSignalKind.unchartedVerge,
        };

    for (final MapEntry<String, ExpeditionNodeSignalKind> entry
        in expected.entries) {
      expect(ExpeditionNodeSignalCatalog.kindFor(entry.key), entry.value);
      expect(
        ExpeditionNodeSignalCatalog.toneFor(entry.key),
        isNot(ExpeditionNodeSignalTone.neutral),
      );
    }
    expect(
      ExpeditionNodeSignalCatalog.kindFor('Внешний маяк'),
      ExpeditionNodeSignalKind.unknown,
    );
    expect(
      ExpeditionNodeSignalCatalog.kindFor('outer-beacon-preview'),
      ExpeditionNodeSignalKind.unknown,
    );
    expect(
      ExpeditionNodeSignalCatalog.kindFor('future-node'),
      ExpeditionNodeSignalKind.unknown,
    );
    expect(
      ExpeditionNodeSignalCatalog.toneFor('future-node'),
      ExpeditionNodeSignalTone.neutral,
    );
  });

  testWidgets('current and next landmarks use accepted copy in both themes', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 220));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final SemanticsHandle semantics = tester.ensureSemantics();

    Future<void> pump(ThemeData theme) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ExpeditionNodeSignal(
                    nodeId: 'second-dawn-threshold',
                    nodeName: 'Порог второго рассвета',
                    completed: false,
                  ),
                  SizedBox(height: 12),
                  ExpeditionNodeSignal(
                    nodeId: 'future-node',
                    nodeName: 'Внешний маяк',
                    completed: false,
                    role: ExpeditionNodeSignalRole.next,
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
      const Key(
        'expedition-node-signal-second-dawn-threshold-secondDawnThreshold',
      ),
    );
    final Finder fallback = find.byKey(
      const Key('expedition-next-node-signal-future-node-unknown'),
    );
    final Finder knownMark = find.byKey(
      const Key(
        'expedition-node-mark-second-dawn-threshold-secondDawnThreshold',
      ),
    );
    final Finder fallbackMark = find.byKey(
      const Key('expedition-next-node-mark-future-node-unknown'),
    );
    expect(known, findsOneWidget);
    expect(fallback, findsOneWidget);
    expect(tester.getSize(knownMark), const Size.square(42));
    expect(tester.getSize(fallbackMark), const Size.square(42));
    for (final Finder mark in <Finder>[knownMark, fallbackMark]) {
      expect(
        find.descendant(of: mark, matching: find.byType(CustomPaint)),
        findsOneWidget,
      );
    }
    expect(
      find.bySemanticsLabel('Текущий узел «Порог второго рассвета»'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Следующий узел «Внешний маяк»'),
      findsOneWidget,
    );
    expect(
      find.descendant(of: fallback, matching: find.byIcon(Icons.arrow_forward)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await pump(WalkingRpgTheme.light());
    expect(known, findsOneWidget);
    expect(fallback, findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('landmark label remains complete at compact enlarged text', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 180));
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
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.topLeft,
              child: ExpeditionNodeSignal(
                nodeId: 'dawn-relay',
                nodeName: 'Ретранслятор рассвета',
                completed: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('РЕТРАНСЛЯТОР РАССВЕТА'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
