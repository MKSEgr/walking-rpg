package com.walkingrpg.backend.home.domain;

import java.time.Instant;
import java.util.List;

import com.fasterxml.jackson.annotation.JsonInclude;

public record ExpeditionJourneyChronicleSnapshot(
        long completedJourneyCount,
        long decisionCount,
        @JsonInclude(JsonInclude.Include.NON_NULL)
        Long totalDurationSeconds,
        @JsonInclude(JsonInclude.Include.NON_NULL)
        Long longestDurationSeconds,
        @JsonInclude(JsonInclude.Include.NON_NULL)
        Long longestJourneyNumber,
        @JsonInclude(JsonInclude.Include.NON_NULL)
        Instant longestJourneyCompletedAt,
        @JsonInclude(JsonInclude.Include.NON_NULL)
        Long averageDurationSeconds,
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
        if (longestDurationSeconds != null
                && (totalDurationSeconds == null
                || longestDurationSeconds < 0
                || longestDurationSeconds > totalDurationSeconds)) {
            throw new IllegalArgumentException(
                    "Самый долгий поход должен входить в суммарную длительность"
            );
        }
        if (longestJourneyNumber != null
                && (longestDurationSeconds == null
                || longestJourneyNumber <= 0
                || longestJourneyNumber > completedJourneyCount)) {
            throw new IllegalArgumentException(
                    "Номер рекордного похода должен входить в летопись"
            );
        }
        if (longestJourneyCompletedAt != null
                && (longestDurationSeconds == null
                || longestJourneyNumber == null)) {
            throw new IllegalArgumentException(
                    "Время рекорда требует подтверждённый рекордный поход"
            );
        }
        if (averageDurationSeconds != null
                && (totalDurationSeconds == null
                || completedJourneyCount <= 0
                || averageDurationSeconds < 0
                || averageDurationSeconds
                != totalDurationSeconds / completedJourneyCount)) {
            throw new IllegalArgumentException(
                    "Средняя длительность должна точно соответствовать итогу"
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
