import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/design_system/event_choice_signal.dart';
import 'package:walking_rpg_mobile/design_system/walking_rpg_theme.dart';
import 'package:walking_rpg_mobile/features/home/presentation/home_screen.dart';
import 'package:walking_rpg_mobile/features/onboarding/domain/first_journey_progress.dart';
import 'package:walking_rpg_mobile/features/onboarding/presentation/first_journey_screen.dart';

import 'support/first_journey_fixture.dart';
import 'support/platform_fixture.dart';

void main() {
  test(
    'selects all current marks only from an exact event and choice pair',
    () {
      var currentPairCount = 0;

      void expectChoice(
        String eventId,
        String choiceId,
        EventChoiceSignalKind kind,
      ) {
        expect(
          EventChoiceSignalCatalog.kindFor(
            eventId: eventId,
            choiceId: choiceId,
          ),
          kind,
        );
        expect(
          EventChoiceSignalCatalog.toneFor(
            eventId: eventId,
            choiceId: choiceId,
          ),
          isNot(EventChoiceSignalTone.neutral),
        );
        currentPairCount += 1;
      }

      expectChoice(
        'signal-source-v1',
        'analyze-signal',
        EventChoiceSignalKind.frequency,
      );
      expectChoice(
        'signal-source-v1',
        'trust-spark',
        EventChoiceSignalKind.companion,
      );
      expectChoice(
        'echo-vault-v1',
        'stabilize-core',
        EventChoiceSignalKind.stabilize,
      );
      expectChoice('echo-vault-v1', 'follow-echo', EventChoiceSignalKind.echo);

      for (final String eventId in const <String>[
        'ash-orbit-v1',
        'glass-marsh-v1',
        'silent-quarry-v1',
        'copper-ravine-v1',
        'ion-garden-v1',
        'frost-antenna-v1',
        'obsidian-crossing-v1',
        'pulse-foundry-v1',
        'mirror-delta-v1',
        'storm-archive-v1',
        'ember-station-v1',
        'aurora-bridge-v1',
        'void-orchard-v1',
        'star-well-v1',
        'horizon-spire-v1',
        'dawn-relay-v1',
      ]) {
        final String suffix = eventId.substring(0, eventId.length - 3);
        expectChoice(eventId, 'survey-$suffix', EventChoiceSignalKind.survey);
        expectChoice(eventId, 'trust-$suffix', EventChoiceSignalKind.companion);
      }

      expectChoice(
        'mirror-delta-v1',
        'follow-resonance',
        EventChoiceSignalKind.resonance,
      );
      expectChoice(
        'resonance-pocket-v1',
        'map-hidden-current',
        EventChoiceSignalKind.chart,
      );
      expectChoice(
        'resonance-pocket-v1',
        'follow-compass-pulse',
        EventChoiceSignalKind.compass,
      );
      expectChoice(
        'star-well-v1',
        'align-prism-sextant',
        EventChoiceSignalKind.prism,
      );
      expectChoice(
        'spectrum-observatory-v1',
        'chart-invisible-constellation',
        EventChoiceSignalKind.chart,
      );
      expectChoice(
        'spectrum-observatory-v1',
        'chase-dawn-refraction',
        EventChoiceSignalKind.prism,
      );
      expectChoice(
        'spectrum-observatory-v1',
        'trace-second-dawn',
        EventChoiceSignalKind.prism,
      );
      expectChoice(
        'dawn-relay-v1',
        'open-second-dawn',
        EventChoiceSignalKind.prism,
      );
      expectChoice(
        'second-dawn-threshold-v1',
        'anchor-second-dawn',
        EventChoiceSignalKind.chart,
      );
      expectChoice(
        'second-dawn-threshold-v1',
        'leap-beyond-dawn',
        EventChoiceSignalKind.companion,
      );
      expectChoice(
        'second-dawn-threshold-v1',
        'cross-uncharted-verge',
        EventChoiceSignalKind.prism,
      );
      expectChoice(
        'uncharted-verge-v1',
        'deploy-return-beacon',
        EventChoiceSignalKind.chart,
      );
      expectChoice(
        'uncharted-verge-v1',
        'follow-living-constellation',
        EventChoiceSignalKind.companion,
      );
      expectChoice(
        'uncharted-verge-v1',
        'ignite-star-trail',
        EventChoiceSignalKind.companion,
      );
      expectChoice(
        'uncharted-verge-v1',
        'root-return-beacon',
        EventChoiceSignalKind.stabilize,
      );
      expectChoice(
        'uncharted-verge-v1',
        'decode-living-constellation',
        EventChoiceSignalKind.echo,
      );
      expectChoice(
        'uncharted-verge-v1',
        'ignite-constellation-gate',
        EventChoiceSignalKind.companion,
      );
      expectChoice(
        'uncharted-verge-v1',
        'root-constellation-gate',
        EventChoiceSignalKind.stabilize,
      );
      expectChoice(
        'uncharted-verge-v1',
        'read-constellation-gate',
        EventChoiceSignalKind.echo,
      );
      expectChoice(
        'constellation-sanctuary-v1',
        'anchor-constellation-sanctuary',
        EventChoiceSignalKind.chart,
      );
      expectChoice(
        'constellation-sanctuary-v1',
        'carry-sanctuary-song',
        EventChoiceSignalKind.companion,
      );
      expect(currentPairCount, 57);

      expect(
        EventChoiceSignalCatalog.kindFor(
          eventId: 'signal-source-v1',
          choiceId: 'trust-companion',
        ),
        EventChoiceSignalKind.companion,
      );
    },
  );

  test('future event-choice combinations remain fully neutral', () {
    for (final ({String eventId, String choiceId}) pair
        in const <({String eventId, String choiceId})>[
          (eventId: 'future-event-v2', choiceId: 'analyze-signal'),
          (eventId: 'signal-source-v1', choiceId: 'future-choice'),
          (eventId: 'signal-source-v1', choiceId: 'follow-echo'),
          (eventId: 'Источник сигнала', choiceId: 'Проанализировать сигнал'),
        ]) {
      expect(
        EventChoiceSignalCatalog.kindFor(
          eventId: pair.eventId,
          choiceId: pair.choiceId,
        ),
        EventChoiceSignalKind.unknown,
      );
      expect(
        EventChoiceSignalCatalog.toneFor(
          eventId: pair.eventId,
          choiceId: pair.choiceId,
        ),
        EventChoiceSignalTone.neutral,
      );
    }
  });

  testWidgets('known and fallback marks stay decorative in both themes', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 180));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final SemanticsHandle semantics = tester.ensureSemantics();

    Future<void> pump(ThemeData theme) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  EventChoiceSignal(
                    eventId: 'echo-vault-v1',
                    choiceId: 'stabilize-core',
                  ),
                  SizedBox(width: 16),
                  EventChoiceSignal(
                    eventId: 'future-event-v2',
                    choiceId: 'stabilize-core',
                    muted: true,
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

    final Finder known = find.byKey(
      const Key(
        'event-choice-signal-echo-vault-v1-stabilize-core-stabilize-active',
      ),
    );
    final Finder fallback = find.byKey(
      const Key(
        'event-choice-signal-future-event-v2-stabilize-core-unknown-muted',
      ),
    );
    for (final Finder signal in <Finder>[known, fallback]) {
      expect(signal, findsOneWidget);
      expect(tester.getSize(signal), const Size.square(52));
      expect(
        find.descendant(of: signal, matching: find.byType(CustomPaint)),
        findsOneWidget,
      );
    }
    expect(find.bySemanticsLabel(RegExp('stabilize|future')), findsNothing);
    expect(tester.takeException(), isNull);

    await pump(WalkingRpgTheme.light());
    expect(known, findsOneWidget);
    expect(fallback, findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('choice layout reflows at compact enlarged text', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 300));
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
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: SizedBox(
              width: 220,
              child: EventChoiceSignalLayout(
                eventId: 'echo-vault-v1',
                choiceId: 'stabilize-core',
                trailing: SizedBox.square(dimension: 42),
                child: Text('Стабилизировать ядро · +30 XP · +8 связь'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const Key('event-choice-layout-echo-vault-v1-stabilize-core-compact'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Стабилизировать ядро'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home and first journey share exact choice identities', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: WalkingRpgTheme.dark(),
        home: HomeScreen(
          loader: () async => firstJourneyHome(eventReady: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(
        const Key(
          'event-choice-signal-signal-source-v1-analyze-signal-frequency-active',
        ),
      ),
      240,
      scrollable: find.byType(Scrollable),
    );
    expect(
      find.byKey(
        const Key(
          'event-choice-signal-signal-source-v1-trust-companion-companion-active',
        ),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    final FirstJourneyProgress progress = FirstJourneyProgress(
      home: firstJourneyHome(synced: true, eventReady: true),
      platform: platformSnapshot(
        completedOnboardingSteps: const <String>['welcome', 'pet-selection'],
        resolvedEventCount: 0,
        totalAcceptedSteps: 3000,
        hasSuccessfulActivitySync: true,
      ),
    );
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
        home: FirstJourneyScreen(
          progress: progress,
          busy: false,
          onWelcome: () {},
          onSync: () {},
          onSelectPet: (_) {},
          onAdvance: () {},
          onResolve: (_) {},
          onContinueAfterActivity: () {},
          onFinish: () {},
          onContinueLater: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(
        const Key(
          'event-choice-layout-signal-source-v1-analyze-signal-compact',
        ),
      ),
      220,
      scrollable: find.byType(Scrollable),
    );

    expect(
      find.byKey(
        const Key(
          'event-choice-layout-signal-source-v1-trust-companion-compact',
        ),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
