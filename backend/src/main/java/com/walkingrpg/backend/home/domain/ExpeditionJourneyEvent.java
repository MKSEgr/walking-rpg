package com.walkingrpg.backend.home.domain;

import java.time.Instant;

public record ExpeditionJourneyEvent(
        String eventId,
        String eventTitle,
        String choiceId,
        String choiceTitle,
        String outcomeTitle,
        String outcomeSummary,
        int pilotExperienceGained,
        String petId,
        String petName,
        int petBondGained,
        MaterialRewardPreviewSnapshot materialReward,
        Instant resolvedAt
) {

    public ExpeditionJourneyEvent(
            String eventId,
            String eventTitle,
            String choiceId,
            String choiceTitle,
            String outcomeTitle,
            String outcomeSummary,
            Instant resolvedAt
    ) {
        this(
                eventId,
                eventTitle,
                choiceId,
                choiceTitle,
                outcomeTitle,
                outcomeSummary,
                0,
                null,
                null,
                0,
                null,
                resolvedAt
        );
    }
}
