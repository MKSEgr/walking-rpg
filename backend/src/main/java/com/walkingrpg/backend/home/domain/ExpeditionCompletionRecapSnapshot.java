package com.walkingrpg.backend.home.domain;

import java.util.List;

public record ExpeditionCompletionRecapSnapshot(
        long journeyNumber,
        int decisionCount,
        List<ExpeditionDecisionSnapshot> decisions,
        ExpeditionFinalDecisionSnapshot finalDecision,
        long pilotExperienceGained,
        long petBondGained,
        List<PetBondRewardSnapshot> petBondRewards,
        List<MaterialRewardPreviewSnapshot> materials
) {
    public ExpeditionCompletionRecapSnapshot {
        decisions = decisions == null ? List.of() : List.copyOf(decisions);
        petBondRewards = petBondRewards == null
                ? List.of()
                : List.copyOf(petBondRewards);
        materials = materials == null ? List.of() : List.copyOf(materials);
    }
}
