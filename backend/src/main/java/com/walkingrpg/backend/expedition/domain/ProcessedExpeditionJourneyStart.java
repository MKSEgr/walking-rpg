package com.walkingrpg.backend.expedition.domain;

public record ProcessedExpeditionJourneyStart(
        String requestFingerprint,
        ExpeditionJourneyStartResult result
) {
}
