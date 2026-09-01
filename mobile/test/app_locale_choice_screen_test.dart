import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/core/localization/app_locale_controller.dart';
import 'package:walking_rpg_mobile/core/localization/app_locale_scope.dart';
import 'package:walking_rpg_mobile/design_system/chapter_vista.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';
import 'package:walking_rpg_mobile/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('Russian is first and continuing persists an explicit choice', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final _MemoryLocaleStore store = _MemoryLocaleStore();
    final AppLocaleController controller = AppLocaleController(store: store);
    addTearDown(controller.dispose);
    await controller.initialize();

    await tester.pumpWidget(
      _LocalizedLocaleApp(
        controller: controller,
        textScaler: const TextScaler.linear(1.6),
        child: AppLocaleChoiceScreen(controller: controller),
      ),
    );

    final Finder russian = find.byKey(const Key('app-locale-choice-ru'));
    final Finder english = find.byKey(const Key('app-locale-choice-en'));
    expect(russian, findsOneWidget);
    expect(english, findsOneWidget);
    expect(find.byType(ChapterVista), findsOneWidget);
    final ChapterVista vista = tester.widget<ChapterVista>(
      find.byKey(const Key('app-locale-gateway-vista')),
    );
    expect(vista.semanticLabel, 'Маршрут к сигнальному маяку');
    expect(find.byKey(const Key('app-locale-mark-ru')), findsOneWidget);
    expect(find.byKey(const Key('app-locale-mark-en')), findsOneWidget);
    expect(
      tester.getTopLeft(russian).dy,
      lessThan(tester.getTopLeft(english).dy),
    );
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(english);
    await tester.tap(english);
    await tester.ensureVisible(find.byKey(const Key('app-locale-continue')));
    await tester.tap(find.byKey(const Key('app-locale-continue')));
    await tester.pump();

    expect(store.value, 'en');
    expect(controller.selected, AppLocale.english);
    expect(controller.requiresExplicitChoice, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('language menu can reverse the persisted preference', (
    WidgetTester tester,
  ) async {
    final _MemoryLocaleStore store = _MemoryLocaleStore(value: 'en');
    final AppLocaleController controller = AppLocaleController(store: store);
    addTearDown(controller.dispose);
    await controller.initialize();

    await tester.pumpWidget(
      _LocalizedLocaleApp(
        controller: controller,
        child: Scaffold(
          appBar: AppBar(actions: const <Widget>[AppLocaleMenuButton()]),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('app-locale-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('app-locale-tile-ru')));
    await tester.pumpAndSettle();

    expect(store.value, 'ru');
    expect(controller.selected, AppLocale.russian);
  });
}

class _LocalizedLocaleApp extends StatelessWidget {
  const _LocalizedLocaleApp({
    required this.controller,
    required this.child,
    this.textScaler = TextScaler.noScaling,
  });

  final AppLocaleController controller;
  final Widget child;
  final TextScaler textScaler;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        return MaterialApp(
          locale: controller.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: WalkingRpgTheme.light(),
          builder: (BuildContext context, Widget? child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: textScaler),
              child: child!,
            );
          },
          home: AppLocaleScope(controller: controller, child: this.child),
        );
      },
    );
  }
}

final class _MemoryLocaleStore implements AppLocaleStore {
  _MemoryLocaleStore({this.value});

  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String languageCode) async {
    value = languageCode;
  }
}
