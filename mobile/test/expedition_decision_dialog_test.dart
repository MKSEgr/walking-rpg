import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/design_system/expedition_decision_dialog.dart';
import 'package:walking_rpg_mobile/design_system/expedition_ui.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

void main() {
  testWidgets('critical decision remains complete in compact enlarged text', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final SemanticsHandle semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    bool? result;

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
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  key: const Key('open-decision-dialog'),
                  onPressed: () async {
                    result = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext context) {
                        return ExpeditionDecisionDialog(
                          badgeLabel: 'Необратимое действие с полным статусом',
                          title: 'Подтвердить изменение?',
                          message:
                              'Решение затрагивает сохранённые данные и не '
                              'должно терять предупреждение или доступные '
                              'действия при увеличенном системном шрифте.',
                          icon: Icons.delete_forever_outlined,
                          confirmLabel: 'Подтвердить изменение',
                          confirmButtonKey: const Key(
                            'compact-decision-confirm',
                          ),
                          destructive: true,
                          tone: ExpeditionPanelTone.neutral,
                          onCancel: () => Navigator.pop(context, false),
                          onConfirm: () => Navigator.pop(context, true),
                        );
                      },
                    );
                  },
                  child: const Text('Открыть'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open-decision-dialog')));
    await tester.pumpAndSettle();

    final Text badge = tester.widget<Text>(
      find.text('НЕОБРАТИМОЕ ДЕЙСТВИЕ С ПОЛНЫМ СТАТУСОМ'),
    );
    expect(badge.maxLines, isNull);
    expect(badge.overflow, TextOverflow.visible);
    final Semantics heading = tester.widget<Semantics>(
      find.byKey(const Key('expedition-decision-heading')),
    );
    expect(heading.properties.header, isTrue);

    await tester.scrollUntilVisible(
      find.byKey(const Key('compact-decision-confirm')),
      160,
      scrollable: find.descendant(
        of: find.byKey(const Key('expedition-decision-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('expedition-decision-cancel')), findsOneWidget);

    await tester.tap(find.byKey(const Key('compact-decision-confirm')));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
