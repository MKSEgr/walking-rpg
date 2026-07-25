package com.walkingrpg.backend.system.api;

import java.time.Instant;

public record SystemInfoResponse(
        String application,
        String version,
        String status,
        Instant serverTime
) {
}
