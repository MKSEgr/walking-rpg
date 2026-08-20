package com.walkingrpg.backend.home.domain;

import java.time.Instant;
import java.util.List;

public record ExpeditionJourneyChronicleTotals(
        long completedJourneyCount,
        long decisionCount,
        Long totalDurationSeconds,
        Long longestDurationSeconds,
        Long longestJourneyNumber,
        Instant longestJourneyCompletedAt,
        long pilotExperienceGained,
        long petBondGained,
        List<ExpeditionJourneyPilotExperienceRewardSnapshot> pilotExperienceRewards,
        List<PetBondRewardSnapshot> petBondRewards,
        List<MaterialRewardPreviewSnapshot> materials,
        List<ExpeditionJourneyDecisionOutcomeSnapshot> decisionOutcomes,
        List<ExpeditionJourneyFinaleOutcomeSnapshot> finaleOutcomes
) {
    public ExpeditionJourneyChronicleTotals {
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

    public ExpeditionJourneyChronicleTotals(
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
        this(
                completedJourneyCount,
                decisionCount,
                null,
                null,
                null,
                null,
                pilotExperienceGained,
                petBondGained,
                pilotExperienceRewards,
                petBondRewards,
                materials,
                decisionOutcomes,
                finaleOutcomes
        );
    }

    public static ExpeditionJourneyChronicleTotals empty() {
        return new ExpeditionJourneyChronicleTotals(
                0,
                0,
                0L,
                0L,
                null,
                null,
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
