import 'package:walking_rpg_mobile/core/localization/mandatory_journey_localizations.dart';
import 'package:walking_rpg_mobile/l10n/generated/app_localizations.dart';

/// Localizes mutable, unresolved event narrative by exact backend identities.
///
/// Callers must keep resolved choices, outcomes, receipts and recap copy
/// literal because those values are immutable records of a completed action.
extension CurrentEventLocalizations on AppLocalizations {
  String currentEventTitle(String eventId, String fallback) {
    return switch (eventId) {
      'signal-source-v1' => journeyEventTitle(eventId, fallback),
      'echo-vault-v1' => catalogEventEchoVaultTitle,
      'ash-orbit-v1' => catalogEventAshOrbitTitle,
      'glass-marsh-v1' => catalogEventGlassMarshTitle,
      'silent-quarry-v1' => catalogEventSilentQuarryTitle,
      'copper-ravine-v1' => catalogEventCopperRavineTitle,
      'ion-garden-v1' => catalogEventIonGardenTitle,
      'frost-antenna-v1' => catalogEventFrostAntennaTitle,
      'obsidian-crossing-v1' => catalogEventObsidianCrossingTitle,
      'pulse-foundry-v1' => catalogEventPulseFoundryTitle,
      'mirror-delta-v1' => catalogEventMirrorDeltaTitle,
      'storm-archive-v1' => catalogEventStormArchiveTitle,
      'ember-station-v1' => catalogEventEmberStationTitle,
      'aurora-bridge-v1' => catalogEventAuroraBridgeTitle,
      'void-orchard-v1' => catalogEventVoidOrchardTitle,
      'star-well-v1' => catalogEventStarWellTitle,
      'horizon-spire-v1' => catalogEventHorizonSpireTitle,
      'dawn-relay-v1' => catalogEventDawnRelayTitle,
      'resonance-pocket-v1' => catalogEventResonancePocketTitle,
      'storm-scriptorium-v1' => catalogEventStormScriptoriumTitle,
      'root-memory-v1' => catalogEventRootMemoryTitle,
      'light-canopy-v1' => catalogEventLightCanopyTitle,
      'spectrum-observatory-v1' => catalogEventSpectrumObservatoryTitle,
      'second-dawn-threshold-v1' => catalogEventSecondDawnThresholdTitle,
      'uncharted-verge-v1' => catalogEventUnchartedVergeTitle,
      'constellation-sanctuary-v1' =>
        catalogEventConstellationSanctuaryTitle,
      'hidden-signal-observatory-v1' =>
        catalogEventHiddenSignalObservatoryTitle,
      'memory-constellation-v1' => catalogEventMemoryConstellationTitle,
      'dawn-meridian-v1' => catalogEventDawnMeridianTitle,
      'first-light-causeway-v1' => catalogEventFirstLightCausewayTitle,
      _ => fallback,
    };
  }

  String currentEventSummary(String eventId, String fallback) {
    return switch (eventId) {
      'signal-source-v1' => journeyEventSummary(eventId, fallback),
      'echo-vault-v1' => catalogEventEchoVaultSummary,
      'ash-orbit-v1' => catalogEventAshOrbitSummary,
      'glass-marsh-v1' => catalogEventGlassMarshSummary,
      'silent-quarry-v1' => catalogEventSilentQuarrySummary,
      'copper-ravine-v1' => catalogEventCopperRavineSummary,
      'ion-garden-v1' => catalogEventIonGardenSummary,
      'frost-antenna-v1' => catalogEventFrostAntennaSummary,
      'obsidian-crossing-v1' => catalogEventObsidianCrossingSummary,
      'pulse-foundry-v1' => catalogEventPulseFoundrySummary,
      'mirror-delta-v1' => catalogEventMirrorDeltaSummary,
      'storm-archive-v1' => catalogEventStormArchiveSummary,
      'ember-station-v1' => catalogEventEmberStationSummary,
      'aurora-bridge-v1' => catalogEventAuroraBridgeSummary,
      'void-orchard-v1' => catalogEventVoidOrchardSummary,
      'star-well-v1' => catalogEventStarWellSummary,
      'horizon-spire-v1' => catalogEventHorizonSpireSummary,
      'dawn-relay-v1' => catalogEventDawnRelaySummary,
      'resonance-pocket-v1' => catalogEventResonancePocketSummary,
      'storm-scriptorium-v1' => catalogEventStormScriptoriumSummary,
      'root-memory-v1' => catalogEventRootMemorySummary,
      'light-canopy-v1' => catalogEventLightCanopySummary,
      'spectrum-observatory-v1' => catalogEventSpectrumObservatorySummary,
      'second-dawn-threshold-v1' => catalogEventSecondDawnThresholdSummary,
      'uncharted-verge-v1' => catalogEventUnchartedVergeSummary,
      'constellation-sanctuary-v1' =>
        catalogEventConstellationSanctuarySummary,
      'hidden-signal-observatory-v1' =>
        catalogEventHiddenSignalObservatorySummary,
      'memory-constellation-v1' => catalogEventMemoryConstellationSummary,
      'dawn-meridian-v1' => catalogEventDawnMeridianSummary,
      'first-light-causeway-v1' => catalogEventFirstLightCausewaySummary,
      _ => fallback,
    };
  }

  String currentEventChoiceTitle(
    String eventId,
    String choiceId,
    String fallback,
  ) {
    if (eventId == 'signal-source-v1') {
      return journeyChoiceTitle(eventId, choiceId, fallback);
    }
    return switch ('$eventId::$choiceId') {
      'echo-vault-v1::stabilize-core' => catalogChoiceStabilizeCoreTitle,
      'echo-vault-v1::follow-echo' => catalogChoiceFollowEchoTitle,
      'ash-orbit-v1::survey-ash-orbit' ||
      'glass-marsh-v1::survey-glass-marsh' ||
      'silent-quarry-v1::survey-silent-quarry' ||
      'copper-ravine-v1::survey-copper-ravine' ||
      'ion-garden-v1::survey-ion-garden' ||
      'frost-antenna-v1::survey-frost-antenna' ||
      'obsidian-crossing-v1::survey-obsidian-crossing' ||
      'pulse-foundry-v1::survey-pulse-foundry' ||
      'mirror-delta-v1::survey-mirror-delta' ||
      'storm-archive-v1::survey-storm-archive' ||
      'ember-station-v1::survey-ember-station' ||
      'aurora-bridge-v1::survey-aurora-bridge' ||
      'void-orchard-v1::survey-void-orchard' ||
      'star-well-v1::survey-star-well' ||
      'horizon-spire-v1::survey-horizon-spire' ||
      'dawn-relay-v1::survey-dawn-relay' => catalogChoiceSurveyNodeTitle,
      'ash-orbit-v1::trust-ash-orbit' ||
      'glass-marsh-v1::trust-glass-marsh' ||
      'silent-quarry-v1::trust-silent-quarry' ||
      'copper-ravine-v1::trust-copper-ravine' ||
      'ion-garden-v1::trust-ion-garden' ||
      'frost-antenna-v1::trust-frost-antenna' ||
      'obsidian-crossing-v1::trust-obsidian-crossing' ||
      'pulse-foundry-v1::trust-pulse-foundry' ||
      'mirror-delta-v1::trust-mirror-delta' ||
      'storm-archive-v1::trust-storm-archive' ||
      'ember-station-v1::trust-ember-station' ||
      'aurora-bridge-v1::trust-aurora-bridge' ||
      'void-orchard-v1::trust-void-orchard' ||
      'star-well-v1::trust-star-well' ||
      'horizon-spire-v1::trust-horizon-spire' ||
      'dawn-relay-v1::trust-dawn-relay' => catalogChoiceTrustNodeTitle,
      'mirror-delta-v1::follow-resonance' =>
        catalogChoiceFollowResonanceTitle,
      'resonance-pocket-v1::map-hidden-current' =>
        catalogChoiceMapHiddenCurrentTitle,
      'resonance-pocket-v1::follow-compass-pulse' =>
        catalogChoiceFollowCompassPulseTitle,
      'storm-archive-v1::enter-storm-rift' =>
        catalogChoiceEnterStormRiftTitle,
      'storm-scriptorium-v1::decode-lightning-script' =>
        catalogChoiceDecodeLightningScriptTitle,
      'storm-scriptorium-v1::chase-rolling-thunder' =>
        catalogChoiceChaseRollingThunderTitle,
      'void-orchard-v1::descend-root-echo' =>
        catalogChoiceDescendRootEchoTitle,
      'void-orchard-v1::climb-light-canopy' =>
        catalogChoiceClimbLightCanopyTitle,
      'root-memory-v1::map-root-memory' => catalogChoiceMapRootMemoryTitle,
      'root-memory-v1::wake-buried-seed' => catalogChoiceWakeBuriedSeedTitle,
      'light-canopy-v1::calibrate-light-fruit' =>
        catalogChoiceCalibrateLightFruitTitle,
      'light-canopy-v1::leap-between-rays' =>
        catalogChoiceLeapBetweenRaysTitle,
      'star-well-v1::align-prism-sextant' =>
        catalogChoiceAlignPrismSextantTitle,
      'spectrum-observatory-v1::chart-invisible-constellation' =>
        catalogChoiceChartInvisibleConstellationTitle,
      'spectrum-observatory-v1::chase-dawn-refraction' =>
        catalogChoiceChaseDawnRefractionTitle,
      'spectrum-observatory-v1::trace-second-dawn' =>
        catalogChoiceTraceSecondDawnTitle,
      'dawn-relay-v1::open-second-dawn' => catalogChoiceOpenSecondDawnTitle,
      'second-dawn-threshold-v1::anchor-second-dawn' =>
        catalogChoiceAnchorSecondDawnTitle,
      'second-dawn-threshold-v1::leap-beyond-dawn' =>
        catalogChoiceLeapBeyondDawnTitle,
      'second-dawn-threshold-v1::cross-uncharted-verge' =>
        catalogChoiceCrossUnchartedVergeTitle,
      'uncharted-verge-v1::deploy-return-beacon' =>
        catalogChoiceDeployReturnBeaconTitle,
      'uncharted-verge-v1::follow-living-constellation' =>
        catalogChoiceFollowLivingConstellationTitle,
      'uncharted-verge-v1::ignite-star-trail' =>
        catalogChoiceIgniteStarTrailTitle,
      'uncharted-verge-v1::root-return-beacon' =>
        catalogChoiceRootReturnBeaconTitle,
      'uncharted-verge-v1::decode-living-constellation' =>
        catalogChoiceDecodeLivingConstellationTitle,
      'uncharted-verge-v1::ignite-constellation-gate' =>
        catalogChoiceIgniteConstellationGateTitle,
      'uncharted-verge-v1::root-constellation-gate' =>
        catalogChoiceRootConstellationGateTitle,
      'uncharted-verge-v1::read-constellation-gate' =>
        catalogChoiceReadConstellationGateTitle,
      'constellation-sanctuary-v1::anchor-constellation-sanctuary' =>
        catalogChoiceAnchorConstellationSanctuaryTitle,
      'constellation-sanctuary-v1::carry-sanctuary-song' =>
        catalogChoiceCarrySanctuarySongTitle,
      'constellation-sanctuary-v1::decode-sanctuary-signal' =>
        catalogChoiceDecodeSanctuarySignalTitle,
      'hidden-signal-observatory-v1::chart-hidden-sector' =>
        catalogChoiceChartHiddenSectorTitle,
      'hidden-signal-observatory-v1::preserve-echo-key' =>
        catalogChoicePreserveEchoKeyTitle,
      'hidden-signal-observatory-v1::reconstruct-forgotten-route' =>
        catalogChoiceReconstructForgottenRouteTitle,
      'memory-constellation-v1::archive-return-path' =>
        catalogChoiceArchiveReturnPathTitle,
      'memory-constellation-v1::entrust-memory-to-pet' =>
        catalogChoiceEntrustMemoryToPetTitle,
      'memory-constellation-v1::stabilize-dawn-current' =>
        catalogChoiceStabilizeDawnCurrentTitle,
      'dawn-meridian-v1::anchor-dawn-flow' =>
        catalogChoiceAnchorDawnFlowTitle,
      'dawn-meridian-v1::share-dawn-flow-with-pet' =>
        catalogChoiceShareDawnFlowWithPetTitle,
      'dawn-meridian-v1::cross-first-light-causeway' =>
        catalogChoiceCrossFirstLightCausewayTitle,
      'first-light-causeway-v1::map-first-light-pulse' =>
        catalogChoiceMapFirstLightPulseTitle,
      'first-light-causeway-v1::follow-pets-steady-pace' =>
        catalogChoiceFollowPetsSteadyPaceTitle,
      _ => fallback,
    };
  }

  String currentEventChoiceDescription(
    String eventId,
    String choiceId,
    String fallback,
  ) {
    if (eventId == 'signal-source-v1') {
      return journeyChoiceDescription(eventId, choiceId, fallback);
    }
    return switch ('$eventId::$choiceId') {
      'echo-vault-v1::stabilize-core' =>
        catalogChoiceStabilizeCoreDescription,
      'echo-vault-v1::follow-echo' => catalogChoiceFollowEchoDescription,
      'ash-orbit-v1::survey-ash-orbit' ||
      'glass-marsh-v1::survey-glass-marsh' ||
      'silent-quarry-v1::survey-silent-quarry' ||
      'copper-ravine-v1::survey-copper-ravine' ||
      'ion-garden-v1::survey-ion-garden' ||
      'frost-antenna-v1::survey-frost-antenna' ||
      'obsidian-crossing-v1::survey-obsidian-crossing' ||
      'pulse-foundry-v1::survey-pulse-foundry' ||
      'mirror-delta-v1::survey-mirror-delta' ||
      'storm-archive-v1::survey-storm-archive' ||
      'ember-station-v1::survey-ember-station' ||
      'aurora-bridge-v1::survey-aurora-bridge' ||
      'void-orchard-v1::survey-void-orchard' ||
      'star-well-v1::survey-star-well' ||
      'horizon-spire-v1::survey-horizon-spire' ||
      'dawn-relay-v1::survey-dawn-relay' =>
        catalogChoiceSurveyNodeDescription,
      'ash-orbit-v1::trust-ash-orbit' ||
      'glass-marsh-v1::trust-glass-marsh' ||
      'silent-quarry-v1::trust-silent-quarry' ||
      'copper-ravine-v1::trust-copper-ravine' ||
      'ion-garden-v1::trust-ion-garden' ||
      'frost-antenna-v1::trust-frost-antenna' ||
      'obsidian-crossing-v1::trust-obsidian-crossing' ||
      'pulse-foundry-v1::trust-pulse-foundry' ||
      'mirror-delta-v1::trust-mirror-delta' ||
      'storm-archive-v1::trust-storm-archive' ||
      'ember-station-v1::trust-ember-station' ||
      'aurora-bridge-v1::trust-aurora-bridge' ||
      'void-orchard-v1::trust-void-orchard' ||
      'star-well-v1::trust-star-well' ||
      'horizon-spire-v1::trust-horizon-spire' ||
      'dawn-relay-v1::trust-dawn-relay' =>
        catalogChoiceTrustNodeDescription,
      'mirror-delta-v1::follow-resonance' =>
        catalogChoiceFollowResonanceDescription,
      'resonance-pocket-v1::map-hidden-current' =>
        catalogChoiceMapHiddenCurrentDescription,
      'resonance-pocket-v1::follow-compass-pulse' =>
        catalogChoiceFollowCompassPulseDescription,
      'storm-archive-v1::enter-storm-rift' =>
        catalogChoiceEnterStormRiftDescription,
      'storm-scriptorium-v1::decode-lightning-script' =>
        catalogChoiceDecodeLightningScriptDescription,
      'storm-scriptorium-v1::chase-rolling-thunder' =>
        catalogChoiceChaseRollingThunderDescription,
      'void-orchard-v1::descend-root-echo' =>
        catalogChoiceDescendRootEchoDescription,
      'void-orchard-v1::climb-light-canopy' =>
        catalogChoiceClimbLightCanopyDescription,
      'root-memory-v1::map-root-memory' =>
        catalogChoiceMapRootMemoryDescription,
      'root-memory-v1::wake-buried-seed' =>
        catalogChoiceWakeBuriedSeedDescription,
      'light-canopy-v1::calibrate-light-fruit' =>
        catalogChoiceCalibrateLightFruitDescription,
      'light-canopy-v1::leap-between-rays' =>
        catalogChoiceLeapBetweenRaysDescription,
      'star-well-v1::align-prism-sextant' =>
        catalogChoiceAlignPrismSextantDescription,
      'spectrum-observatory-v1::chart-invisible-constellation' =>
        catalogChoiceChartInvisibleConstellationDescription,
      'spectrum-observatory-v1::chase-dawn-refraction' =>
        catalogChoiceChaseDawnRefractionDescription,
      'spectrum-observatory-v1::trace-second-dawn' =>
        catalogChoiceTraceSecondDawnDescription,
      'dawn-relay-v1::open-second-dawn' =>
        catalogChoiceOpenSecondDawnDescription,
      'second-dawn-threshold-v1::anchor-second-dawn' =>
        catalogChoiceAnchorSecondDawnDescription,
      'second-dawn-threshold-v1::leap-beyond-dawn' =>
        catalogChoiceLeapBeyondDawnDescription,
      'second-dawn-threshold-v1::cross-uncharted-verge' =>
        catalogChoiceCrossUnchartedVergeDescription,
      'uncharted-verge-v1::deploy-return-beacon' =>
        catalogChoiceDeployReturnBeaconDescription,
      'uncharted-verge-v1::follow-living-constellation' =>
        catalogChoiceFollowLivingConstellationDescription,
      'uncharted-verge-v1::ignite-star-trail' =>
        catalogChoiceIgniteStarTrailDescription,
      'uncharted-verge-v1::root-return-beacon' =>
        catalogChoiceRootReturnBeaconDescription,
      'uncharted-verge-v1::decode-living-constellation' =>
        catalogChoiceDecodeLivingConstellationDescription,
      'uncharted-verge-v1::ignite-constellation-gate' =>
        catalogChoiceIgniteConstellationGateDescription,
      'uncharted-verge-v1::root-constellation-gate' =>
        catalogChoiceRootConstellationGateDescription,
      'uncharted-verge-v1::read-constellation-gate' =>
        catalogChoiceReadConstellationGateDescription,
      'constellation-sanctuary-v1::anchor-constellation-sanctuary' =>
        catalogChoiceAnchorConstellationSanctuaryDescription,
      'constellation-sanctuary-v1::carry-sanctuary-song' =>
        catalogChoiceCarrySanctuarySongDescription,
      'constellation-sanctuary-v1::decode-sanctuary-signal' =>
        catalogChoiceDecodeSanctuarySignalDescription,
      'hidden-signal-observatory-v1::chart-hidden-sector' =>
        catalogChoiceChartHiddenSectorDescription,
      'hidden-signal-observatory-v1::preserve-echo-key' =>
        catalogChoicePreserveEchoKeyDescription,
      'hidden-signal-observatory-v1::reconstruct-forgotten-route' =>
        catalogChoiceReconstructForgottenRouteDescription,
      'memory-constellation-v1::archive-return-path' =>
        catalogChoiceArchiveReturnPathDescription,
      'memory-constellation-v1::entrust-memory-to-pet' =>
        catalogChoiceEntrustMemoryToPetDescription,
      'memory-constellation-v1::stabilize-dawn-current' =>
        catalogChoiceStabilizeDawnCurrentDescription,
      'dawn-meridian-v1::anchor-dawn-flow' =>
        catalogChoiceAnchorDawnFlowDescription,
      'dawn-meridian-v1::share-dawn-flow-with-pet' =>
        catalogChoiceShareDawnFlowWithPetDescription,
      'dawn-meridian-v1::cross-first-light-causeway' =>
        catalogChoiceCrossFirstLightCausewayDescription,
      'first-light-causeway-v1::map-first-light-pulse' =>
        catalogChoiceMapFirstLightPulseDescription,
      'first-light-causeway-v1::follow-pets-steady-pace' =>
        catalogChoiceFollowPetsSteadyPaceDescription,
      _ => fallback,
    };
  }

  String currentEventRequirementDescription(
    String eventId,
    String choiceId,
    String fallback,
  ) {
    return switch ('$eventId::$choiceId') {
      'mirror-delta-v1::follow-resonance' =>
        catalogRequirementFollowResonance,
      'storm-archive-v1::enter-storm-rift' =>
        catalogRequirementEnterStormRift,
      'star-well-v1::align-prism-sextant' =>
        catalogRequirementAlignPrismSextant,
      'spectrum-observatory-v1::trace-second-dawn' =>
        catalogRequirementTraceSecondDawn,
      'dawn-relay-v1::open-second-dawn' =>
        catalogRequirementOpenSecondDawn,
      'second-dawn-threshold-v1::cross-uncharted-verge' =>
        catalogRequirementCrossUnchartedVerge,
      'uncharted-verge-v1::ignite-star-trail' =>
        catalogRequirementIgniteStarTrail,
      'uncharted-verge-v1::root-return-beacon' =>
        catalogRequirementRootReturnBeacon,
      'uncharted-verge-v1::decode-living-constellation' =>
        catalogRequirementDecodeLivingConstellation,
      'uncharted-verge-v1::ignite-constellation-gate' =>
        catalogRequirementIgniteConstellationGate,
      'uncharted-verge-v1::root-constellation-gate' =>
        catalogRequirementRootConstellationGate,
      'uncharted-verge-v1::read-constellation-gate' =>
        catalogRequirementReadConstellationGate,
      'constellation-sanctuary-v1::decode-sanctuary-signal' =>
        catalogRequirementDecodeSanctuarySignal,
      'hidden-signal-observatory-v1::reconstruct-forgotten-route' =>
        catalogRequirementReconstructForgottenRoute,
      'memory-constellation-v1::stabilize-dawn-current' =>
        catalogRequirementStabilizeDawnCurrent,
      'dawn-meridian-v1::cross-first-light-causeway' =>
        catalogRequirementCrossFirstLightCauseway,
      _ => fallback,
    };
  }
}
