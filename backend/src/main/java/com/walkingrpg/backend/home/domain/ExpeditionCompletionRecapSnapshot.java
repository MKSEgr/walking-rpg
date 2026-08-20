package com.walkingrpg.backend.home.domain;

import java.util.List;

import com.fasterxml.jackson.annotation.JsonInclude;

public record ExpeditionCompletionRecapSnapshot(
        long journeyNumber,
        int decisionCount,
        List<ExpeditionDecisionSnapshot> decisions,
        ExpeditionFinalDecisionSnapshot finalDecision,
        long pilotExperienceGained,
        @JsonInclude(JsonInclude.Include.NON_EMPTY)
        List<ExpeditionJourneyPilotExperienceRewardSnapshot> pilotExperienceRewards,
        long petBondGained,
        List<PetBondRewardSnapshot> petBondRewards,
        List<MaterialRewardPreviewSnapshot> materials
) {
    public ExpeditionCompletionRecapSnapshot {
        decisions = decisions == null ? List.of() : List.copyOf(decisions);
        pilotExperienceRewards = pilotExperienceRewards == null
                ? List.of()
                : List.copyOf(pilotExperienceRewards);
        petBondRewards = petBondRewards == null
                ? List.of()
                : List.copyOf(petBondRewards);
        materials = materials == null ? List.of() : List.copyOf(materials);
    }
}
