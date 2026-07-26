package com.walkingrpg.backend.expedition.domain;

public record EventResolutionCommand(
        String userId,
        String eventId,
        String choiceId,
        String idempotencyKey
) {
}
