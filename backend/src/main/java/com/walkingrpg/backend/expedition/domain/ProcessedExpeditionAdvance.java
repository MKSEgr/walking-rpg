package com.walkingrpg.backend.expedition.domain;

public record ProcessedExpeditionAdvance(
        String requestFingerprint,
        ExpeditionAdvanceResult result
) {
}
