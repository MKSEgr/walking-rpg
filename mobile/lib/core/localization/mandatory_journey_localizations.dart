import 'package:walking_rpg_mobile/l10n/generated/app_localizations.dart';

extension MandatoryJourneyLocalizations on AppLocalizations {
  String journeyPetName(String petId, String fallback) {
    return switch (petId) {
      'spark-v1' => petSparkName,
      'moss-v1' => petMossName,
      'rune-v1' => petRuneName,
      _ => fallback,
    };
  }

  String journeyPetSpecies(String petId, String fallback) {
    return switch (petId) {
      'spark-v1' => petSparkSpecies,
      'moss-v1' => petMossSpecies,
      'rune-v1' => petRuneSpecies,
      _ => fallback,
    };
  }

  String journeyPetTrait(String petId, String fallback) {
    return switch (petId) {
      'spark-v1' => petSparkTrait,
      'moss-v1' => petMossTrait,
      'rune-v1' => petRuneTrait,
      _ => fallback,
    };
  }

  String journeyPilotName(String pilotId, String fallback) {
    return pilotId == 'navigator-v1' ? pilotNavigatorName : fallback;
  }

  String journeyNodeName(String nodeId, String fallback) {
    return switch (nodeId) {
      'outer-beacon' => nodeOuterBeaconName,
      'lumen-gate' => nodeLumenGateName,
      _ => fallback,
    };
  }

  String journeyEventTitle(String eventId, String fallback) {
    return eventId == 'signal-source-v1' ? eventSignalSourceTitle : fallback;
  }

  String journeyEventSummary(String eventId, String fallback) {
    return eventId == 'signal-source-v1' ? eventSignalSourceSummary : fallback;
  }

  String journeyChoiceTitle(String eventId, String choiceId, String fallback) {
    if (eventId != 'signal-source-v1') {
      return fallback;
    }
    return switch (choiceId) {
      'analyze-signal' => choiceAnalyzeSignalTitle,
      'trust-companion' || 'trust-spark' => choiceTrustCompanionTitle,
      _ => fallback,
    };
  }

  String journeyChoiceDescription(
    String eventId,
    String choiceId,
    String fallback,
  ) {
    if (eventId != 'signal-source-v1') {
      return fallback;
    }
    return switch (choiceId) {
      'analyze-signal' => choiceAnalyzeSignalDescription,
      'trust-companion' || 'trust-spark' => choiceTrustCompanionDescription,
      _ => fallback,
    };
  }

  String journeyOutcomeTitle(String eventId, String choiceId, String fallback) {
    return eventId == 'signal-source-v1' && choiceId == 'analyze-signal'
        ? outcomeSignalAnalyzedTitle
        : fallback;
  }

  String journeyOutcomeSummary(
    String eventId,
    String choiceId,
    String fallback,
  ) {
    return eventId == 'signal-source-v1' && choiceId == 'analyze-signal'
        ? outcomeSignalAnalyzedSummary
        : fallback;
  }

  String journeyRiskStatus(String status) {
    return switch (status.toUpperCase()) {
      'ACCEPTED' => riskStatusAccepted,
      'REVIEW' || 'UNDER_REVIEW' => riskStatusReview,
      'REJECTED' => riskStatusRejected,
      _ => status,
    };
  }

  String companionStageName(int stage) {
    final int normalized = stage < 0 ? 0 : stage;
    return switch (normalized) {
      0 => companionBabyStage,
      1 => companionYoungStage,
      2 => companionAdultStage,
      _ => companionFutureStage(normalized + 1),
    };
  }

  String companionFormLabel(int stage) {
    final int normalized = stage < 0 ? 0 : stage;
    final String name = companionStageName(normalized);
    return normalized < 3
        ? companionIllustratedForm(name, normalized + 1)
        : name;
  }

  String companionPortraitDescription({
    required String name,
    required String species,
    required int stage,
    required bool active,
    required bool hasSparkHalo,
  }) {
    final String activeLabel = active ? ', $companionActiveSemantic' : '';
    final String cosmeticLabel = hasSparkHalo ? ', $companionSparkHalo' : '';
    return companionPortraitSemantics(
      name,
      species,
      companionFormLabel(stage),
      activeLabel,
      cosmeticLabel,
    );
  }

  String eventSceneDescription(String eventId, String eventTitle) {
    return switch (eventId) {
      'signal-source-v1' => signalSourceSceneSemantics(eventTitle),
      'echo-vault-v1' => echoVaultSceneSemantics(eventTitle),
      'mirror-delta-v1' => mirrorDeltaSceneSemantics(eventTitle),
      'resonance-pocket-v1' => resonancePocketSceneSemantics(eventTitle),
      _ => eventFallbackScene(eventTitle),
    };
  }
}
