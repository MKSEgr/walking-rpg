package com.walkingrpg.backend.platform.api;

import java.time.Instant;

public record PlatformCommandResponse(
        String commandType,
        String idempotencyKey,
        String message,
        long stateVersion,
        PlatformSnapshotResponse snapshot,
        Instant serverTime
) {
}
