package com.walkingrpg.backend.home.domain;

import java.util.List;

public record ExpeditionJourneyChronicleTotals(
        long completedJourneyCount,
        long decisionCount,
        long pilotExperienceGained,
        long petBondGained,
        List<PetBondRewardSnapshot> petBondRewards,
        List<MaterialRewardPreviewSnapshot> materials
) {
    public ExpeditionJourneyChronicleTotals {
        petBondRewards = petBondRewards == null
                ? List.of()
                : List.copyOf(petBondRewards);
        materials = materials == null
                ? List.of()
                : List.copyOf(materials);
    }

    public static ExpeditionJourneyChronicleTotals empty() {
        return new ExpeditionJourneyChronicleTotals(
                0,
                0,
                0,
                0,
                List.of(),
                List.of()
        );
    }
}
