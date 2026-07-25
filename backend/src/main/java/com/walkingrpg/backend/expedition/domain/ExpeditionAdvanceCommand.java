package com.walkingrpg.backend.expedition.domain;

public record ExpeditionAdvanceCommand(
        String userId,
        String expeditionId,
        long energyToSpend,
        String idempotencyKey
) {
}
