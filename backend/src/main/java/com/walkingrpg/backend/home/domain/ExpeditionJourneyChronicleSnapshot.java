package com.walkingrpg.backend.home.domain;

import java.util.List;

import com.fasterxml.jackson.annotation.JsonInclude;

public record ExpeditionJourneyChronicleSnapshot(
        long completedJourneyCount,
        long decisionCount,
        @JsonInclude(JsonInclude.Include.NON_NULL)
        Long totalDurationSeconds,
        long pilotExperienceGained,
        long petBondGained,
        @JsonInclude(JsonInclude.Include.NON_EMPTY)
        List<ExpeditionJourneyPilotExperienceRewardSnapshot> pilotExperienceRewards,
        List<PetBondRewardSnapshot> petBondRewards,
        List<MaterialRewardPreviewSnapshot> materials,
        @JsonInclude(JsonInclude.Include.NON_EMPTY)
        List<ExpeditionJourneyDecisionOutcomeSnapshot> decisionOutcomes,
        @JsonInclude(JsonInclude.Include.NON_EMPTY)
        List<ExpeditionJourneyFinaleOutcomeSnapshot> finaleOutcomes
) {
    public ExpeditionJourneyChronicleSnapshot {
        if (totalDurationSeconds != null && totalDurationSeconds < 0) {
            throw new IllegalArgumentException(
                    "Суммарная длительность походов не может быть отрицательной"
            );
        }
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
}
