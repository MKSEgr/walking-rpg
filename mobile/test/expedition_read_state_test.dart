import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/design_system/expedition_read_state.dart';
import 'package:walking_rpg_mobile/design_system/expedition_ui.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';

void main() {
  testWidgets('loading state remains readable on compact enlarged text', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 480));
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
          body: ExpeditionBackdrop(
            child: ExpeditionReadState.loading(
              title: 'Сверяем маршрут',
              message: 'Получаем только актуальное серверное состояние.',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('СВЯЗЬ С МАРШРУТОМ'), findsOneWidget);
    expect(find.text('Сверяем маршрут'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Получение актуального состояния'),
      findsOneWidget,
    );
    final Semantics heading = tester.widget<Semantics>(
      find.byKey(const Key('expedition-read-state-heading')),
    );
    expect(heading.container, isTrue);
    expect(heading.properties.header, isTrue);

    semantics.dispose();
  });

  testWidgets('failure state exposes explicit recovery actions', (
    WidgetTester tester,
  ) async {
    int retries = 0;
    int secondaryActions = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.light(),
        home: Scaffold(
          body: ExpeditionReadState.failure(
            title: 'Сигнал потерян',
            message: 'Актуальное состояние не принято.',
            details: 'Backend недоступен',
            primaryActionKey: const Key('retry'),
            primaryActionLabel: 'Повторить',
            onPrimaryAction: () {
              retries += 1;
            },
            secondaryActionKey: const Key('secondary'),
            secondaryActionLabel: 'Открыть локальное состояние',
            onSecondaryAction: () {
              secondaryActions += 1;
            },
          ),
        ),
      ),
    );

    expect(find.text('СИГНАЛ НЕДОСТУПЕН'), findsOneWidget);
    expect(find.text('Backend недоступен'), findsOneWidget);
    await tester.tap(find.byKey(const Key('retry')));
    await tester.tap(find.byKey(const Key('secondary')));

    expect(retries, 1);
    expect(secondaryActions, 1);
  });
}
