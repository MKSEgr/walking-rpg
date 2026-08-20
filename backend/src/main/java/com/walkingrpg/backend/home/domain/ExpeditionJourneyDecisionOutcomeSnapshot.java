package com.walkingrpg.backend.home.domain;

public record ExpeditionJourneyDecisionOutcomeSnapshot(
        String eventId,
        String eventTitle,
        String choiceId,
        String choiceTitle,
        String outcomeTitle,
        long decisionCount
) {
}
