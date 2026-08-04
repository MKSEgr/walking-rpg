import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/design_system/expedition_item_art.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

void main() {
  test('item artwork is selected only from exact stable IDs', () {
    expect(
      ExpeditionItemArtwork.assetPathFor('lumen-shard'),
      'assets/items/lumen_shard.webp',
    );
    expect(
      ExpeditionItemArtwork.assetPathFor('echo-thread'),
      'assets/items/echo_thread.webp',
    );
    expect(
      ExpeditionItemArtwork.assetPathFor('resonance-compass'),
      'assets/items/resonance_compass.webp',
    );
    expect(ExpeditionItemArtwork.assetPathFor('Lumen Shard'), isNull);
    expect(ExpeditionItemArtwork.assetPathFor('unknown-item'), isNull);
  });

  testWidgets('known item art and unknown fallback remain presentation only', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        home: const Scaffold(
          body: Wrap(
            children: <Widget>[
              ExpeditionItemEmblem(itemId: 'lumen-shard'),
              ExpeditionItemEmblem(itemId: 'echo-thread'),
              ExpeditionItemEmblem(
                itemId: 'resonance-compass',
                highlighted: true,
              ),
              ExpeditionItemEmblem(itemId: 'unknown-item'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('item-art-lumen-shard')), findsOneWidget);
    expect(find.byKey(const Key('item-art-echo-thread')), findsOneWidget);
    expect(find.byKey(const Key('item-art-resonance-compass')), findsOneWidget);
    expect(
      find.byKey(const Key('item-art-fallback-unknown-item')),
      findsOneWidget,
    );
    expect(find.byType(Image), findsNWidgets(3));
    expect(find.bySemanticsLabel('lumen-shard'), findsNothing);
    expect(tester.takeException(), isNull);

    semantics.dispose();
  });
}
