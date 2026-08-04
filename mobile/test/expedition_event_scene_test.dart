import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/design_system/expedition_event_scene.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

void main() {
  test('event artwork is selected only from exact stable IDs', () {
    expect(
      ExpeditionEventArtwork.assetPathFor('signal-source-v1'),
      'assets/events/signal_source.webp',
    );
    expect(
      ExpeditionEventArtwork.assetPathFor('echo-vault-v1'),
      'assets/events/echo_vault.webp',
    );
    expect(
      ExpeditionEventArtwork.assetPathFor('mirror-delta-v1'),
      'assets/events/mirror_delta.webp',
    );
    expect(
      ExpeditionEventArtwork.assetPathFor('resonance-pocket-v1'),
      'assets/events/resonance_pocket.webp',
    );
    expect(ExpeditionEventArtwork.assetPathFor('Signal Source'), isNull);
    expect(ExpeditionEventArtwork.assetPathFor('signal-source-v2'), isNull);
    expect(ExpeditionEventArtwork.assetPathFor('unknown-event'), isNull);
  });

  testWidgets('committed scene assets are available to the Flutter bundle', (
    WidgetTester tester,
  ) async {
    for (final String path in <String>[
      'assets/events/signal_source.webp',
      'assets/events/echo_vault.webp',
      'assets/events/mirror_delta.webp',
      'assets/events/resonance_pocket.webp',
    ]) {
      final ByteData data = await rootBundle.load(path);
      expect(data.lengthInBytes, greaterThan(0), reason: path);
    }
  });

  testWidgets('known scene and unknown fallback keep accessible identities', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final SemanticsHandle semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              children: <Widget>[
                ExpeditionEventScene(
                  eventId: 'signal-source-v1',
                  fallbackSemanticLabel: 'Не используется',
                ),
                SizedBox(height: 16),
                ExpeditionEventScene(
                  eventId: 'future-event-v1',
                  fallbackSemanticLabel: 'Сцена события «Источник сигнала»',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder known = find.byKey(const Key('event-scene-signal-source-v1'));
    expect(known, findsOneWidget);
    expect(
      find.byKey(const Key('event-scene-fallback-future-event-v1')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Сцена события «Источник сигнала»: внешний маяк посылает '
        'повторяющиеся импульсы сквозь туман.',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Сцена события «Источник сигнала»'),
      findsOneWidget,
    );
    expect(tester.getSize(known), const Size(272, 153));
    expect(tester.takeException(), isNull);

    semantics.dispose();
  });
}
