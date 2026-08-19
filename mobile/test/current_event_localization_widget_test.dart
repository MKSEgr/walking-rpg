import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walking_rpg_mobile/core/localization/current_event_localizations.dart';
import 'package:walking_rpg_mobile/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('current event catalog covers every reviewed stable identity', (
    WidgetTester tester,
  ) async {
    expect(_eventIds.toSet(), hasLength(30));
    expect(_choicePairs.toSet(), hasLength(78));
    expect(_requirementPairs.toSet(), hasLength(16));

    for (final Locale locale in const <Locale>[Locale('ru'), Locale('en')]) {
      late AppLocalizations l10n;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (BuildContext context) {
              l10n = AppLocalizations.of(context)!;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final String eventId in _eventIds) {
        expect(
          l10n.currentEventTitle(eventId, _fallback),
          isNot(_fallback),
          reason: '${locale.languageCode} event title $eventId',
        );
        expect(
          l10n.currentEventSummary(eventId, _fallback),
          isNot(_fallback),
          reason: '${locale.languageCode} event summary $eventId',
        );
      }
      for (final (String, String) pair in _choicePairs) {
        expect(
          l10n.currentEventChoiceTitle(pair.$1, pair.$2, _fallback),
          isNot(_fallback),
          reason: '${locale.languageCode} choice title ${pair.$1}::${pair.$2}',
        );
        expect(
          l10n.currentEventChoiceDescription(pair.$1, pair.$2, _fallback),
          isNot(_fallback),
          reason:
              '${locale.languageCode} choice description '
              '${pair.$1}::${pair.$2}',
        );
      }
      for (final (String, String) pair in _requirementPairs) {
        expect(
          l10n.currentEventRequirementDescription(pair.$1, pair.$2, _fallback),
          isNot(_fallback),
          reason: '${locale.languageCode} requirement ${pair.$1}::${pair.$2}',
        );
      }

      if (locale.languageCode == 'en') {
        expect(
          l10n.currentEventTitle('echo-vault-v1', _fallback),
          'Echo Vault',
        );
        expect(
          l10n.currentEventTitle('first-light-causeway-v1', _fallback),
          'Step Above the Dawn',
        );
        expect(
          l10n.currentEventChoiceTitle(
            'uncharted-verge-v1',
            'read-constellation-gate',
            _fallback,
          ),
          'Read the gate with Constellation Navigator',
        );
        expect(
          l10n.currentEventRequirementDescription(
            'dawn-meridian-v1',
            'cross-first-light-causeway',
            _fallback,
          ),
          'Unlock Steady Step to cross on the first light.',
        );
      }
    }
  });

  testWidgets('unknown event identities preserve literal server copy', (
    WidgetTester tester,
  ) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) {
            l10n = AppLocalizations.of(context)!;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(l10n.currentEventTitle('future-event-v2', _fallback), _fallback);
    expect(l10n.currentEventSummary('future-event-v2', _fallback), _fallback);
    expect(
      l10n.currentEventChoiceTitle('echo-vault-v1', 'future-choice', _fallback),
      _fallback,
    );
    expect(
      l10n.currentEventChoiceDescription(
        'future-event-v2',
        'stabilize-core',
        _fallback,
      ),
      _fallback,
    );
    expect(
      l10n.currentEventRequirementDescription(
        'future-event-v2',
        'future-choice',
        _fallback,
      ),
      _fallback,
    );
  });
}

const String _fallback = 'Literal copy from a newer server';

const List<String> _eventIds = <String>[
  'signal-source-v1',
  'echo-vault-v1',
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
  'resonance-pocket-v1',
  'storm-scriptorium-v1',
  'root-memory-v1',
  'light-canopy-v1',
  'spectrum-observatory-v1',
  'second-dawn-threshold-v1',
  'uncharted-verge-v1',
  'constellation-sanctuary-v1',
  'hidden-signal-observatory-v1',
  'memory-constellation-v1',
  'dawn-meridian-v1',
  'first-light-causeway-v1',
];

const List<(String, String)> _choicePairs = <(String, String)>[
  ('signal-source-v1', 'analyze-signal'),
  ('signal-source-v1', 'trust-spark'),
  ('echo-vault-v1', 'stabilize-core'),
  ('echo-vault-v1', 'follow-echo'),
  ('ash-orbit-v1', 'survey-ash-orbit'),
  ('ash-orbit-v1', 'trust-ash-orbit'),
  ('glass-marsh-v1', 'survey-glass-marsh'),
  ('glass-marsh-v1', 'trust-glass-marsh'),
  ('silent-quarry-v1', 'survey-silent-quarry'),
  ('silent-quarry-v1', 'trust-silent-quarry'),
  ('copper-ravine-v1', 'survey-copper-ravine'),
  ('copper-ravine-v1', 'trust-copper-ravine'),
  ('ion-garden-v1', 'survey-ion-garden'),
  ('ion-garden-v1', 'trust-ion-garden'),
  ('frost-antenna-v1', 'survey-frost-antenna'),
  ('frost-antenna-v1', 'trust-frost-antenna'),
  ('obsidian-crossing-v1', 'survey-obsidian-crossing'),
  ('obsidian-crossing-v1', 'trust-obsidian-crossing'),
  ('pulse-foundry-v1', 'survey-pulse-foundry'),
  ('pulse-foundry-v1', 'trust-pulse-foundry'),
  ('mirror-delta-v1', 'survey-mirror-delta'),
  ('mirror-delta-v1', 'trust-mirror-delta'),
  ('mirror-delta-v1', 'follow-resonance'),
  ('storm-archive-v1', 'survey-storm-archive'),
  ('storm-archive-v1', 'trust-storm-archive'),
  ('storm-archive-v1', 'enter-storm-rift'),
  ('ember-station-v1', 'survey-ember-station'),
  ('ember-station-v1', 'trust-ember-station'),
  ('aurora-bridge-v1', 'survey-aurora-bridge'),
  ('aurora-bridge-v1', 'trust-aurora-bridge'),
  ('void-orchard-v1', 'survey-void-orchard'),
  ('void-orchard-v1', 'trust-void-orchard'),
  ('void-orchard-v1', 'descend-root-echo'),
  ('void-orchard-v1', 'climb-light-canopy'),
  ('star-well-v1', 'survey-star-well'),
  ('star-well-v1', 'trust-star-well'),
  ('star-well-v1', 'align-prism-sextant'),
  ('horizon-spire-v1', 'survey-horizon-spire'),
  ('horizon-spire-v1', 'trust-horizon-spire'),
  ('dawn-relay-v1', 'survey-dawn-relay'),
  ('dawn-relay-v1', 'trust-dawn-relay'),
  ('dawn-relay-v1', 'open-second-dawn'),
  ('resonance-pocket-v1', 'map-hidden-current'),
  ('resonance-pocket-v1', 'follow-compass-pulse'),
  ('storm-scriptorium-v1', 'decode-lightning-script'),
  ('storm-scriptorium-v1', 'chase-rolling-thunder'),
  ('root-memory-v1', 'map-root-memory'),
  ('root-memory-v1', 'wake-buried-seed'),
  ('light-canopy-v1', 'calibrate-light-fruit'),
  ('light-canopy-v1', 'leap-between-rays'),
  ('spectrum-observatory-v1', 'chart-invisible-constellation'),
  ('spectrum-observatory-v1', 'chase-dawn-refraction'),
  ('spectrum-observatory-v1', 'trace-second-dawn'),
  ('second-dawn-threshold-v1', 'anchor-second-dawn'),
  ('second-dawn-threshold-v1', 'leap-beyond-dawn'),
  ('second-dawn-threshold-v1', 'cross-uncharted-verge'),
  ('uncharted-verge-v1', 'deploy-return-beacon'),
  ('uncharted-verge-v1', 'follow-living-constellation'),
  ('uncharted-verge-v1', 'ignite-star-trail'),
  ('uncharted-verge-v1', 'root-return-beacon'),
  ('uncharted-verge-v1', 'decode-living-constellation'),
  ('uncharted-verge-v1', 'ignite-constellation-gate'),
  ('uncharted-verge-v1', 'root-constellation-gate'),
  ('uncharted-verge-v1', 'read-constellation-gate'),
  ('constellation-sanctuary-v1', 'anchor-constellation-sanctuary'),
  ('constellation-sanctuary-v1', 'carry-sanctuary-song'),
  ('constellation-sanctuary-v1', 'decode-sanctuary-signal'),
  ('hidden-signal-observatory-v1', 'chart-hidden-sector'),
  ('hidden-signal-observatory-v1', 'preserve-echo-key'),
  ('hidden-signal-observatory-v1', 'reconstruct-forgotten-route'),
  ('memory-constellation-v1', 'archive-return-path'),
  ('memory-constellation-v1', 'entrust-memory-to-pet'),
  ('memory-constellation-v1', 'stabilize-dawn-current'),
  ('dawn-meridian-v1', 'anchor-dawn-flow'),
  ('dawn-meridian-v1', 'share-dawn-flow-with-pet'),
  ('dawn-meridian-v1', 'cross-first-light-causeway'),
  ('first-light-causeway-v1', 'map-first-light-pulse'),
  ('first-light-causeway-v1', 'follow-pets-steady-pace'),
];

const List<(String, String)> _requirementPairs = <(String, String)>[
  ('mirror-delta-v1', 'follow-resonance'),
  ('storm-archive-v1', 'enter-storm-rift'),
  ('star-well-v1', 'align-prism-sextant'),
  ('spectrum-observatory-v1', 'trace-second-dawn'),
  ('dawn-relay-v1', 'open-second-dawn'),
  ('second-dawn-threshold-v1', 'cross-uncharted-verge'),
  ('uncharted-verge-v1', 'ignite-star-trail'),
  ('uncharted-verge-v1', 'root-return-beacon'),
  ('uncharted-verge-v1', 'decode-living-constellation'),
  ('uncharted-verge-v1', 'ignite-constellation-gate'),
  ('uncharted-verge-v1', 'root-constellation-gate'),
  ('uncharted-verge-v1', 'read-constellation-gate'),
  ('constellation-sanctuary-v1', 'decode-sanctuary-signal'),
  ('hidden-signal-observatory-v1', 'reconstruct-forgotten-route'),
  ('memory-constellation-v1', 'stabilize-dawn-current'),
  ('dawn-meridian-v1', 'cross-first-light-causeway'),
];
