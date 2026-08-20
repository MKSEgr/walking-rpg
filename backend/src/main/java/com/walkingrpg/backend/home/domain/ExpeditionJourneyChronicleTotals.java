package com.walkingrpg.backend.home.domain;

import java.util.List;

public record ExpeditionJourneyChronicleTotals(
        long completedJourneyCount,
        long decisionCount,
        long pilotExperienceGained,
        long petBondGained,
        List<ExpeditionJourneyPilotExperienceRewardSnapshot> pilotExperienceRewards,
        List<PetBondRewardSnapshot> petBondRewards,
        List<MaterialRewardPreviewSnapshot> materials,
        List<ExpeditionJourneyDecisionOutcomeSnapshot> decisionOutcomes,
        List<ExpeditionJourneyFinaleOutcomeSnapshot> finaleOutcomes
) {
    public ExpeditionJourneyChronicleTotals {
        pilotExperienceRewards = pilotExperienceRewards == null
                ? List.of()
                : List.copyOf(pilotExperienceRewards);
        petBondRewards = petBondRewards == null
                ? List.of()
                : List.copyOf(petBondRewards);
        materials = materials == null
                ? List.of()
                : List.copyOf(materials);
        decisionOutcomes = decisionOutcomes == null
                ? List.of()
                : List.copyOf(decisionOutcomes);
        finaleOutcomes = finaleOutcomes == null
                ? List.of()
                : List.copyOf(finaleOutcomes);
    }

    public static ExpeditionJourneyChronicleTotals empty() {
        return new ExpeditionJourneyChronicleTotals(
                0,
                0,
                0,
                0,
                List.of(),
                List.of(),
                List.of(),
                List.of(),
                List.of()
        );
    }
}
