package com.walkingrpg.backend.home.domain;

import java.util.List;

public record ExpeditionCompletionRecapSnapshot(
        long journeyNumber,
        int decisionCount,
        ExpeditionFinalDecisionSnapshot finalDecision,
        long pilotExperienceGained,
        long petBondGained,
        List<PetBondRewardSnapshot> petBondRewards,
        List<MaterialRewardPreviewSnapshot> materials
) {
    public ExpeditionCompletionRecapSnapshot {
        petBondRewards = petBondRewards == null
                ? List.of()
                : List.copyOf(petBondRewards);
        materials = materials == null ? List.of() : List.copyOf(materials);
    }
}
