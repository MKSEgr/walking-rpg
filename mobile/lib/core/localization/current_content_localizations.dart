import 'package:walking_rpg_mobile/core/localization/mandatory_journey_localizations.dart';
import 'package:walking_rpg_mobile/l10n/generated/app_localizations.dart';

/// Localizes mutable current-content identities by their stable backend IDs.
///
/// The backend copy remains the literal fallback for stale snapshots and for
/// content introduced by a newer server. Persisted journey history must not use
/// these helpers because its copy is an immutable record of what the player saw.
extension CurrentContentLocalizations on AppLocalizations {
  String currentExpeditionName(String expeditionId, String fallback) {
    return expeditionId == 'starter-expedition-v1'
        ? catalogStarterExpeditionName
        : fallback;
  }

  String currentNodeName(String nodeId, String fallback) {
    return switch (nodeId) {
      'outer-beacon' => nodeOuterBeaconName,
      'lumen-gate' => nodeLumenGateName,
      'ash-orbit' => catalogNodeAshOrbitName,
      'glass-marsh' => catalogNodeGlassMarshName,
      'silent-quarry' => catalogNodeSilentQuarryName,
      'copper-ravine' => catalogNodeCopperRavineName,
      'ion-garden' => catalogNodeIonGardenName,
      'frost-antenna' => catalogNodeFrostAntennaName,
      'obsidian-crossing' => catalogNodeObsidianCrossingName,
      'pulse-foundry' => catalogNodePulseFoundryName,
      'mirror-delta' => catalogNodeMirrorDeltaName,
      'storm-archive' => catalogNodeStormArchiveName,
      'ember-station' => catalogNodeEmberStationName,
      'aurora-bridge' => catalogNodeAuroraBridgeName,
      'void-orchard' => catalogNodeVoidOrchardName,
      'star-well' => catalogNodeStarWellName,
      'horizon-spire' => catalogNodeHorizonSpireName,
      'dawn-relay' => catalogNodeDawnRelayName,
      'resonance-pocket' => catalogNodeResonancePocketName,
      'storm-scriptorium' => catalogNodeStormScriptoriumName,
      'root-memory' => catalogNodeRootMemoryName,
      'light-canopy' => catalogNodeLightCanopyName,
      'spectrum-observatory' => catalogNodeSpectrumObservatoryName,
      'second-dawn-threshold' => catalogNodeSecondDawnThresholdName,
      'uncharted-verge' => catalogNodeUnchartedVergeName,
      'constellation-sanctuary' => catalogNodeConstellationSanctuaryName,
      'hidden-signal-observatory' =>
        catalogNodeHiddenSignalObservatoryName,
      'memory-constellation' => catalogNodeMemoryConstellationName,
      'dawn-meridian' => catalogNodeDawnMeridianName,
      'first-light-causeway' => catalogNodeFirstLightCausewayName,
      _ => fallback,
    };
  }

  String currentPilotName(String? pilotId, String fallback) {
    return pilotId == null ? fallback : journeyPilotName(pilotId, fallback);
  }

  String currentPetName(String? petId, String fallback) {
    return petId == null ? fallback : journeyPetName(petId, fallback);
  }

  String currentPetSpecies(String? petId, String fallback) {
    return petId == null ? fallback : journeyPetSpecies(petId, fallback);
  }

  String currentItemName(String itemId, String fallback) {
    return switch (itemId) {
      'lumen-shard' => catalogItemLumenShardName,
      'echo-thread' => catalogItemEchoThreadName,
      'ash-seed' => catalogItemAshSeedName,
      'prism-dust' => catalogItemPrismDustName,
      'ion-bloom' => catalogItemIonBloomName,
      'dawn-fragment' => catalogItemDawnFragmentName,
      'resonance-compass' => catalogItemResonanceCompassName,
      'prism-sextant' => catalogItemPrismSextantName,
      _ => fallback,
    };
  }

  String currentItemDescription(String itemId, String fallback) {
    return switch (itemId) {
      'lumen-shard' => catalogItemLumenShardDescription,
      'echo-thread' => catalogItemEchoThreadDescription,
      'ash-seed' => catalogItemAshSeedDescription,
      'prism-dust' => catalogItemPrismDustDescription,
      'ion-bloom' => catalogItemIonBloomDescription,
      'dawn-fragment' => catalogItemDawnFragmentDescription,
      'resonance-compass' => catalogItemResonanceCompassDescription,
      'prism-sextant' => catalogItemPrismSextantDescription,
      _ => fallback,
    };
  }

  String currentEquipmentSlotName(String slotId, String fallback) {
    return slotId == 'NAVIGATION'
        ? catalogEquipmentNavigationSlotName
        : fallback;
  }

  String currentEquipmentSlotDescription(String slotId, String fallback) {
    return slotId == 'NAVIGATION'
        ? catalogEquipmentNavigationSlotDescription
        : fallback;
  }

  String currentRecipeName(String recipeId, String fallback) {
    return switch (recipeId) {
      'resonance-compass-v1' => catalogRecipeResonanceCompassName,
      'prism-sextant-v1' => catalogRecipePrismSextantName,
      _ => fallback,
    };
  }

  String currentRecipeDescription(String recipeId, String fallback) {
    return switch (recipeId) {
      'resonance-compass-v1' => catalogRecipeResonanceCompassDescription,
      'prism-sextant-v1' => catalogRecipePrismSextantDescription,
      _ => fallback,
    };
  }

  String currentUpgradeName(String upgradeId, String fallback) {
    return switch (upgradeId) {
      'prism-sextant-calibration-v1' =>
        catalogUpgradePrismSextantCalibrationName,
      'prism-sextant-second-dawn-attunement-v1' =>
        catalogUpgradePrismSextantSecondDawnName,
      _ => fallback,
    };
  }

  String currentUpgradeDescription(String upgradeId, String fallback) {
    return switch (upgradeId) {
      'prism-sextant-calibration-v1' =>
        catalogUpgradePrismSextantCalibrationDescription,
      'prism-sextant-second-dawn-attunement-v1' =>
        catalogUpgradePrismSextantSecondDawnDescription,
      _ => fallback,
    };
  }
}
