package com.walkingrpg.backend.home.domain;

public record ExpeditionJourneyFinaleOutcomeSnapshot(
        String eventId,
        String eventTitle,
        String choiceId,
        String choiceTitle,
        String outcomeTitle,
        long journeyCount
) {
}
