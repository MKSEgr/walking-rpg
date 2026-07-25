package com.walkingrpg.backend.activity.domain;

import java.time.Instant;

public record ActivitySyncResult(
        long acceptedTotal,
        long acceptedDelta,
        long energyGranted,
        ActivityRiskStatus riskStatus,
        long stateVersion,
        Instant serverTime
) {
}
