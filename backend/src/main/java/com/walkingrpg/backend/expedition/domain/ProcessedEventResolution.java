package com.walkingrpg.backend.expedition.domain;

public record ProcessedEventResolution(
        String requestFingerprint,
        EventResolutionResult result
) {
}
