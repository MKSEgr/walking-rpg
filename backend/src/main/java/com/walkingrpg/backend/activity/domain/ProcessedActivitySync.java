package com.walkingrpg.backend.activity.domain;

public record ProcessedActivitySync(
        ActivitySyncCommand command,
        ActivitySyncResult result
) {
}
