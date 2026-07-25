package com.walkingrpg.backend.home.domain;

import java.time.Instant;

public record HomeRuntimeState(
        long dailySteps,
        long activityStateVersion,
        String timeZone,
        Instant lastActivitySyncAt,
        long availableEnergy,
        long economyVersion
) {
    public HomeRuntimeState {
        if (dailySteps < 0 || activityStateVersion < 0) {
            throw new IllegalArgumentException("Activity state не может быть отрицательным");
        }
        if (availableEnergy < 0 || economyVersion < 0) {
            throw new IllegalArgumentException("Economy state не может быть отрицательным");
        }
    }
}
