import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';
import 'package:walking_rpg_mobile/features/activity/domain/activity_sync_result.dart';
import 'package:walking_rpg_mobile/features/auth/presentation/auth_expedition_screen.dart';
import 'package:walking_rpg_mobile/features/event/domain/event_resolution_result.dart';
import 'package:walking_rpg_mobile/features/onboarding/domain/first_journey_progress.dart';
import 'package:walking_rpg_mobile/features/onboarding/presentation/first_journey_screen.dart';
import 'package:walking_rpg_mobile/l10n/generated/app_localizations.dart';

import 'support/first_journey_fixture.dart';
import 'support/platform_fixture.dart';

void main() {
  testWidgets(
    'registration entry renders Russian and English without overflow',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final ({Locale locale, String signIn}) localeCase
          in <({Locale locale, String signIn})>[
            (locale: const Locale('ru'), signIn: 'Войти в экспедицию'),
            (locale: const Locale('en'), signIn: 'Sign in to the expedition'),
          ]) {
        await tester.pumpWidget(
          _LocalizedTestApp(
            locale: localeCase.locale,
            child: AuthExpeditionScreen(
              reauthentication: false,
              busy: false,
              onSignIn: () {},
            ),
          ),
        );
        await tester.scrollUntilVisible(
          find.byKey(const Key('oidc-sign-in-button')),
          240,
          scrollable: find.byType(Scrollable),
        );

        expect(find.text(localeCase.signIn), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('every mandatory first-journey panel renders in both locales', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final ({Locale locale, List<String> expected}) localeCase
        in <({Locale locale, List<String> expected})>[
          (
            locale: const Locale('ru'),
            expected: <String>[
              'Твой путь начинается с реальных шагов',
              'Подключи шаги и получи первую ENERGY',
              'Кто пойдёт к сигналу вместе с тобой?',
              'Внешний маяк',
              'Источник сигнала',
              'Экспедиция открыта',
              'ДВИЖЕНИЕ ПОДТВЕРЖДЕНО',
              'Частота найдена',
            ],
          ),
          (
            locale: const Locale('en'),
            expected: <String>[
              'Your journey begins with real steps',
              'Connect steps and earn your first ENERGY',
              'Who will follow the signal with you?',
              'Outer Beacon',
              'Signal Source',
              'Expedition unlocked',
              'MOVEMENT CONFIRMED',
              'Frequency found',
            ],
          ),
        ]) {
      final List<FirstJourneyScreen> screens = _mandatoryScreens();
      expect(screens.length, localeCase.expected.length);

      for (int index = 0; index < screens.length; index += 1) {
        await tester.pumpWidget(
          _LocalizedTestApp(locale: localeCase.locale, child: screens[index]),
        );
        await tester.pump();

        expect(
          find.text(localeCase.expected[index]),
          findsOneWidget,
          reason:
              '${localeCase.locale.languageCode} mandatory panel $index '
              'must use its localized inventory',
        );
        expect(tester.takeException(), isNull);
      }
    }
  });
}

List<FirstJourneyScreen> _mandatoryScreens() {
  final FirstJourneyProgress welcome = FirstJourneyProgress(
    home: firstJourneyHome(),
    platform: platformSnapshot(
      completedOnboardingSteps: const <String>[],
      resolvedEventCount: 0,
      totalAcceptedSteps: 0,
      hasSuccessfulActivitySync: false,
    ),
  );
  final FirstJourneyProgress activity = FirstJourneyProgress(
    home: firstJourneyHome(),
    platform: platformSnapshot(
      completedOnboardingSteps: const <String>['welcome'],
      resolvedEventCount: 0,
      totalAcceptedSteps: 0,
      hasSuccessfulActivitySync: false,
    ),
  );
  final FirstJourneyProgress pet = FirstJourneyProgress(
    home: firstJourneyHome(synced: true),
    platform: platformSnapshot(
      completedOnboardingSteps: const <String>['welcome'],
      resolvedEventCount: 0,
      totalAcceptedSteps: 3000,
      hasSuccessfulActivitySync: true,
    ),
  );
  final FirstJourneyProgress expedition = FirstJourneyProgress(
    home: firstJourneyHome(synced: true, energy: 30),
    platform: platformSnapshot(
      completedOnboardingSteps: const <String>['welcome', 'pet-selection'],
      resolvedEventCount: 0,
      totalAcceptedSteps: 3000,
      hasSuccessfulActivitySync: true,
    ),
  );
  final FirstJourneyProgress event = FirstJourneyProgress(
    home: firstJourneyHome(synced: true, eventReady: true),
    platform: platformSnapshot(
      completedOnboardingSteps: const <String>['welcome', 'pet-selection'],
      resolvedEventCount: 0,
      totalAcceptedSteps: 3000,
      hasSuccessfulActivitySync: true,
    ),
  );
  final FirstJourneyProgress complete = FirstJourneyProgress(
    home: firstJourneyHome(synced: true, firstEventResolved: true),
    platform: platformSnapshot(
      completedOnboardingSteps: FirstJourneyProgress.steps,
      resolvedEventCount: 1,
      totalAcceptedSteps: 3000,
      hasSuccessfulActivitySync: true,
    ),
  );

  return <FirstJourneyScreen>[
    _screen(welcome),
    _screen(activity),
    _screen(pet),
    _screen(expedition),
    _screen(event),
    _screen(complete),
    _screen(pet, activityReward: firstJourneyActivityResult),
    _screen(complete, eventReward: firstJourneyResolutionResult()),
  ];
}

FirstJourneyScreen _screen(
  FirstJourneyProgress progress, {
  ActivitySyncResult? activityReward,
  EventResolutionResult? eventReward,
}) {
  return FirstJourneyScreen(
    progress: progress,
    busy: false,
    activityReward: activityReward,
    eventReward: eventReward,
    onWelcome: () {},
    onSync: () {},
    onSelectPet: (_) {},
    onAdvance: () {},
    onResolve: (_) {},
    onContinueAfterActivity: () {},
    onFinish: () {},
    onContinueLater: () {},
  );
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
