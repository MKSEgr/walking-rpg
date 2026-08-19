import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/app/expedition_boundary_screen.dart';
import 'package:walking_rpg_mobile/design_system/expedition_ui.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';
import 'package:walking_rpg_mobile/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('loading boundary is indeterminate and announces launch state', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        home: const ExpeditionBoundaryScreen.loading(
          badgeLabel: 'Канал экспедиции',
          title: 'Восстанавливаем маршрут',
          message: 'Проверяем защищённую сессию.',
          icon: Icons.shield_outlined,
        ),
      ),
    );

    expect(find.byType(ExpeditionBackdrop), findsOneWidget);
    expect(find.text('КАНАЛ ЭКСПЕДИЦИИ'), findsOneWidget);
    expect(find.text('Восстанавливаем маршрут'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .value,
      isNull,
    );
    expect(
      find.bySemanticsLabel('Операция запуска выполняется'),
      findsOneWidget,
    );
    final Semantics heading = tester.widget<Semantics>(
      find.byKey(const Key('expedition-boundary-heading')),
    );
    expect(heading.properties.header, isTrue);

    semantics.dispose();
  });

  testWidgets('blocked boundary keeps diagnostics readable in compact layout', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final SemanticsHandle semantics = tester.ensureSemantics();

    const String diagnostic =
        'OIDC issuer, client identifier and redirect configuration could not '
        'be validated for this development launch.';
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: WalkingRpgTheme.light(),
        builder: (BuildContext context, Widget? child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          );
        },
        home: const ExpeditionBoundaryScreen.blocked(
          badgeLabel: 'Launch boundary with a long name',
          title: 'Launch stopped safely',
          message: 'Check the configuration and restart the application.',
          details: diagnostic,
          icon: Icons.security_outlined,
          tone: ExpeditionPanelTone.resonance,
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('expedition-boundary-details')),
      180,
      scrollable: find.byType(Scrollable),
    );

    final Text badge = tester.widget<Text>(
      find.text('LAUNCH BOUNDARY WITH A LONG NAME'),
    );
    expect(badge.maxLines, isNull);
    expect(badge.overflow, TextOverflow.visible);
    expect(find.text(diagnostic), findsOneWidget);
    expect(find.bySemanticsLabel('Launch safely blocked'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
