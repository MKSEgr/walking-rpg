import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/design_system/chapter_vista.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';
import 'package:walking_rpg_mobile/features/auth/presentation/auth_expedition_screen.dart';

void main() {
  testWidgets('entry screen presents the expedition without invented state', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final SemanticsHandle semantics = tester.ensureSemantics();
    int signInCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        home: AuthExpeditionScreen(
          reauthentication: false,
          busy: false,
          onSignIn: () {
            signInCalls += 1;
          },
        ),
      ),
    );

    expect(find.byKey(const Key('auth-title')), findsOneWidget);
    expect(find.text('КАНАЛ ЭКСПЕДИЦИИ'), findsOneWidget);
    expect(find.text('БЕЗ GPS'), findsOneWidget);
    expect(find.text('ТОЛЬКО ШАГИ · ЧТЕНИЕ'), findsOneWidget);
    expect(find.textContaining('Telegram'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Туманный сектор и сигнальный маяк'),
      findsOneWidget,
    );
    final ChapterVista vista = tester.widget<ChapterVista>(
      find.byKey(const Key('auth-chapter-vista')),
    );
    expect(vista.progress, isNull);

    await tester.tap(find.byKey(const Key('oidc-sign-in-button')));
    expect(signInCalls, 1);

    semantics.dispose();
  });

  testWidgets('reauthentication keeps controller status and disables sign-in', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.light(),
        home: AuthExpeditionScreen(
          reauthentication: true,
          busy: true,
          message: 'Сервер входа временно недоступен.',
          notice: 'Предыдущая сессия завершена безопасно.',
          onSignIn: () {},
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('oidc-sign-in-button')),
      180,
      scrollable: find.byType(Scrollable),
    );

    expect(find.text('ТРЕБУЕТСЯ ПОВТОРНЫЙ ВХОД'), findsOneWidget);
    expect(find.text('Вернуться в экспедицию'), findsOneWidget);
    expect(find.byKey(const Key('auth-message')), findsOneWidget);
    expect(find.byKey(const Key('auth-notice')), findsOneWidget);
    expect(find.text('Сервер входа временно недоступен.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('oidc-sign-in-button')))
          .onPressed,
      isNull,
    );
    expect(find.text('Открываем защищённый вход...'), findsOneWidget);
  });

  testWidgets('compact entry remains scrollable with enlarged text', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
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
        home: AuthExpeditionScreen(
          reauthentication: false,
          busy: false,
          onSignIn: () {},
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('oidc-sign-in-button')),
      220,
      scrollable: find.byType(Scrollable),
    );

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('oidc-sign-in-button')), findsOneWidget);
  });
}
