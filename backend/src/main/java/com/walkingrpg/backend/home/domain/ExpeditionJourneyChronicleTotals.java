package com.walkingrpg.backend.home.domain;

import java.util.List;

public record ExpeditionJourneyChronicleTotals(
        long completedJourneyCount,
        long decisionCount,
        long pilotExperienceGained,
        long petBondGained,
        List<PetBondRewardSnapshot> petBondRewards
) {
    public ExpeditionJourneyChronicleTotals {
        petBondRewards = petBondRewards == null
                ? List.of()
                : List.copyOf(petBondRewards);
    }

    public static ExpeditionJourneyChronicleTotals empty() {
        return new ExpeditionJourneyChronicleTotals(
                0,
                0,
                0,
                0,
                List.of()
        );
    }
}
