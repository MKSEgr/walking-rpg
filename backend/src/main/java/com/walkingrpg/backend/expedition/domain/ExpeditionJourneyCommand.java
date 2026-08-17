package com.walkingrpg.backend.expedition.domain;

public record ExpeditionJourneyCommand(
        String userId,
        String expeditionId,
        long expectedJourneyNumber,
        String idempotencyKey
) {
}
