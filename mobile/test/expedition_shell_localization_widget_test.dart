import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/app/main_navigation_shell.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';
import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';
import 'package:walking_rpg_mobile/features/home/presentation/home_screen.dart';
import 'package:walking_rpg_mobile/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('compact post-onboarding shell follows RU and EN at large text', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final _ShellLocaleCase localeCase in <_ShellLocaleCase>[
      const _ShellLocaleCase(
        locale: Locale('ru'),
        expedition: 'Экспедиция',
        journal: 'Журнал',
        waiting: 'Экспедиция ждёт твоих шагов',
        crew: 'Команда экспедиции',
        savedActions: 'Сохранённые действия',
        companionSemantic: 'активный спутник',
        expeditionName: 'Сигнал из туманного сектора',
        nodeName: 'Внешний маяк',
        petName: 'Искра',
        currentNodeSemantic:
            'Текущий узел «Внешний маяк»',
      ),
      const _ShellLocaleCase(
        locale: Locale('en'),
        expedition: 'Expedition',
        journal: 'Journal',
        waiting: 'The expedition is waiting for your steps',
        crew: 'Expedition crew',
        savedActions: 'Saved actions',
        companionSemantic: 'active companion',
        expeditionName: 'Signal from the Fog Sector',
        nodeName: 'Outer Beacon',
        petName: 'Spark',
        currentNodeSemantic: 'Current node “Outer Beacon”',
      ),
    ]) {
      await tester.pumpWidget(
        _LocalizedTestApp(
          locale: localeCase.locale,
          child: MainNavigationShell(
            home: HomeScreen(loader: () async => HomeSnapshot.demo),
            platform: const Center(child: Text('platform-placeholder')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(localeCase.expedition), findsOneWidget);
      expect(find.text(localeCase.journal), findsOneWidget);
      expect(find.text(localeCase.waiting), findsOneWidget);
      expect(find.text(localeCase.expeditionName), findsAtLeastNWidgets(1));
      expect(find.text(localeCase.nodeName), findsAtLeastNWidgets(1));
      expect(find.textContaining(localeCase.petName), findsAtLeastNWidgets(1));
      expect(
        find.bySemanticsLabel(localeCase.currentNodeSemantic),
        findsOneWidget,
      );
      expect(find.byTooltip(localeCase.savedActions), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          RegExp(RegExp.escape(localeCase.companionSemantic)),
        ),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(
        find.text(localeCase.crew),
        220,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text(localeCase.crew), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('wide terminal navigation follows RU and EN locale', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1180, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final ({Locale locale, String terminal, String journal}) localeCase
        in <({Locale locale, String terminal, String journal})>[
          (
            locale: const Locale('ru'),
            terminal: 'ПОЛЕВОЙ ТЕРМИНАЛ',
            journal: 'Журнал',
          ),
          (
            locale: const Locale('en'),
            terminal: 'FIELD TERMINAL',
            journal: 'Journal',
          ),
        ]) {
      await tester.pumpWidget(
        _LocalizedTestApp(
          locale: localeCase.locale,
          child: const MainNavigationShell(
            home: Center(child: Text('home-placeholder')),
            platform: Center(child: Text('platform-placeholder')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text(localeCase.terminal), findsOneWidget);
      expect(find.text(localeCase.journal), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}

class _LocalizedTestApp extends StatelessWidget {
  const _LocalizedTestApp({required this.locale, required this.child});

  final Locale locale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: WalkingRpgTheme.dark(),
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        );
      },
      home: child,
    );
  }
}

class _ShellLocaleCase {
  const _ShellLocaleCase({
    required this.locale,
    required this.expedition,
    required this.journal,
    required this.waiting,
    required this.crew,
    required this.savedActions,
    required this.companionSemantic,
    required this.expeditionName,
    required this.nodeName,
    required this.petName,
    required this.currentNodeSemantic,
  });

  final Locale locale;
  final String expedition;
  final String journal;
  final String waiting;
  final String crew;
  final String savedActions;
  final String companionSemantic;
  final String expeditionName;
  final String nodeName;
  final String petName;
  final String currentNodeSemantic;
}
