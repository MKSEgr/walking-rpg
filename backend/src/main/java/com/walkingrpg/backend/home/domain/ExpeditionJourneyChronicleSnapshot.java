package com.walkingrpg.backend.home.domain;

import java.util.List;

public record ExpeditionJourneyChronicleSnapshot(
        long completedJourneyCount,
        long decisionCount,
        long pilotExperienceGained,
        long petBondGained,
        List<PetBondRewardSnapshot> petBondRewards
) {
    public ExpeditionJourneyChronicleSnapshot {
        petBondRewards = petBondRewards == null
                ? List.of()
                : List.copyOf(petBondRewards);
    }
}
