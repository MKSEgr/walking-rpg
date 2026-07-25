package com.walkingrpg.backend.activity.api;

import java.time.Instant;

import com.walkingrpg.backend.activity.domain.ActivityRiskStatus;

public record ActivitySyncResponse(
        long acceptedTotal,
        long acceptedDelta,
        long energyGranted,
        ActivityRiskStatus riskStatus,
        long stateVersion,
        Instant serverTime
) {
}
