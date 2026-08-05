import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/design_system/equipment_mount_signal.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

void main() {
  test('selects mount and item identities only from exact stable IDs', () {
    expect(
      EquipmentMountSignalCatalog.kindFor('NAVIGATION'),
      EquipmentMountSignalKind.navigation,
    );
    expect(
      EquipmentMountSignalCatalog.kindFor('Navigation'),
      EquipmentMountSignalKind.unknown,
    );
    expect(
      EquipmentMountSignalCatalog.itemKindFor(null),
      EquipmentMountItemKind.empty,
    );
    expect(
      EquipmentMountSignalCatalog.itemKindFor('resonance-compass'),
      EquipmentMountItemKind.resonanceCompass,
    );
    expect(
      EquipmentMountSignalCatalog.itemKindFor('Резонансный компас'),
      EquipmentMountItemKind.unknown,
    );
    expect(
      EquipmentMountSignalCatalog.itemKindFor('future-instrument'),
      EquipmentMountItemKind.unknown,
    );
    expect(
      EquipmentMountSignalCatalog.stateFor(
        slotId: 'NAVIGATION',
        status: 'EMPTY',
        itemId: null,
      ),
      EquipmentMountSignalState.navigationEmpty,
    );
    expect(
      EquipmentMountSignalCatalog.stateFor(
        slotId: 'NAVIGATION',
        status: 'EQUIPPED',
        itemId: 'resonance-compass',
      ),
      EquipmentMountSignalState.resonanceCompassMounted,
    );
    expect(
      EquipmentMountSignalCatalog.stateFor(
        slotId: 'NAVIGATION',
        status: 'EQUIPPED',
        itemId: 'future-instrument',
      ),
      EquipmentMountSignalState.neutral,
    );
    expect(
      EquipmentMountSignalCatalog.stateFor(
        slotId: 'future-slot',
        status: 'EQUIPPED',
        itemId: 'resonance-compass',
      ),
      EquipmentMountSignalState.neutral,
    );
  });

  testWidgets(
    'known, empty and fallback mounts stay decorative in both themes',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 420));
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
                  children: <Widget>[
                    EquipmentMountSignal(
                      slotId: 'NAVIGATION',
                      status: 'EQUIPPED',
                      itemId: 'resonance-compass',
                    ),
                    SizedBox(height: 12),
                    EquipmentMountSignal(
                      slotId: 'NAVIGATION',
                      status: 'EMPTY',
                      itemId: null,
                    ),
                    SizedBox(height: 12),
                    EquipmentMountSignal(
                      slotId: 'future-slot',
                      status: 'EQUIPPED',
                      itemId: 'future-instrument',
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

      final List<Finder> mounts = <Finder>[
        find.byKey(
          const Key(
            'equipment-mount-signal-NAVIGATION-navigation-'
            'resonanceCompass-EQUIPPED',
          ),
        ),
        find.byKey(
          const Key('equipment-mount-signal-NAVIGATION-navigation-empty-EMPTY'),
        ),
        find.byKey(
          const Key(
            'equipment-mount-signal-future-slot-unknown-unknown-EQUIPPED',
          ),
        ),
      ];
      for (final Finder mount in mounts) {
        expect(mount, findsOneWidget);
        expect(tester.getSize(mount).height, 112);
        expect(
          find.descendant(of: mount, matching: find.byType(CustomPaint)),
          findsOneWidget,
        );
      }
      expect(
        find.bySemanticsLabel(RegExp('слот|компас|снаряжение')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);

      await pump(WalkingRpgTheme.light());
      for (final Finder mount in mounts) {
        expect(mount, findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
}
