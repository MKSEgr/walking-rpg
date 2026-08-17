package com.walkingrpg.backend.home.domain;

import java.time.Instant;

public record ExpeditionDecisionSnapshot(
        String eventId,
        String eventTitle,
        String choiceId,
        String choiceTitle,
        String outcomeTitle,
        String outcomeSummary,
        Instant resolvedAt
) {
}
