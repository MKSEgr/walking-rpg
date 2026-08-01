package com.walkingrpg.backend.platform.analytics;

import java.time.Instant;
import java.util.List;

public record CompassJourneyAnalyticsSnapshot(
        String cohortCode,
        long eligibleUsers,
        long instrumentedUsers,
        double instrumentationRate,
        List<CompassJourneyFunnel> funnels,
        CompassJourneyDataQuality dataQuality,
        Instant generatedAt
) {
    public CompassJourneyAnalyticsSnapshot {
        funnels = List.copyOf(funnels);
    }
}
