import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/app/main_navigation_shell.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';
import 'package:walking_rpg_mobile/features/home/domain/home_snapshot.dart';
import 'package:walking_rpg_mobile/features/home/presentation/home_screen.dart';
import 'package:walking_rpg_mobile/l10n/generated/app_localizations.dart';

void main() {
  testWidgets(
    'compact post-onboarding shell follows RU and EN at large text',
    (WidgetTester tester) async {
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
          companionSemanticFragment: 'активный спутник',
        ),
        const _ShellLocaleCase(
          locale: Locale('en'),
          expedition: 'Expedition',
          journal: 'Journal',
          waiting: 'The expedition is waiting for your steps',
          crew: 'Expedition crew',
          savedActions: 'Saved actions',
          companionSemanticFragment: 'active companion',
        ),
      ]) {
        await tester.pumpWidget(_LocalizedShell(localeCase.locale));
        await tester.pumpAndSettle();

        expect(find.text(localeCase.expedition), findsOneWidget);
        expect(find.text(localeCase.journal), findsOneWidget);
        expect(find.text(localeCase.waiting), findsOneWidget);
        expect(find.byTooltip(localeCase.savedActions), findsOneWidget);
        expect(
          find.bySemanticsLabel(
            RegExp(RegExp.escape(localeCase.companionSemanticFragment)),
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
    },
  );

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
        _LocalizedShell(localeCase.locale, usePlaceholderDestinations: true),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text(localeCase.terminal), findsOneWidget);
      expect(find.text(localeCase.journal), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}

class _LocalizedShell extends StatelessWidget {
  const _LocalizedShell(this.locale, {this.usePlaceholderDestinations = false});

  final Locale locale;
  final bool usePlaceholderDestinations;

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
      home: MainNavigationShell(
        home: usePlaceholderDestinations
            ? const Center(child: Text('home-placeholder'))
            : HomeScreen(loader: () async => HomeSnapshot.demo),
        platform: const Center(child: Text('platform-placeholder')),
      ),
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
    required this.companionSemanticFragment,
  });

  final Locale locale;
  final String expedition;
  final String journal;
  final String waiting;
  final String crew;
  final String savedActions;
  final String companionSemanticFragment;
}
