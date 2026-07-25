package com.walkingrpg.backend.activity.domain;

public record ProcessedActivitySync(
        String requestFingerprint,
        ActivitySyncResult result
) {
}
