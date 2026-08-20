package com.walkingrpg.backend.home.domain;

import java.util.List;

import com.fasterxml.jackson.annotation.JsonInclude;

public record ExpeditionJourneyChronicleSnapshot(
        long completedJourneyCount,
        long decisionCount,
        long pilotExperienceGained,
        long petBondGained,
        List<PetBondRewardSnapshot> petBondRewards,
        List<MaterialRewardPreviewSnapshot> materials,
        @JsonInclude(JsonInclude.Include.NON_EMPTY)
        List<ExpeditionJourneyDecisionOutcomeSnapshot> decisionOutcomes,
        @JsonInclude(JsonInclude.Include.NON_EMPTY)
        List<ExpeditionJourneyFinaleOutcomeSnapshot> finaleOutcomes
) {
    public ExpeditionJourneyChronicleSnapshot {
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
}
