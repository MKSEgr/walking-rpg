package com.walkingrpg.backend.platform.analytics;

import java.time.Instant;
import java.util.List;

public record FirstJourneyAnalyticsSnapshot(
        String cohortCode,
        long eligibleUsers,
        long startedUsers,
        long notStartedUsers,
        double startRate,
        List<FirstJourneyStageMetric> stages,
        FirstJourneyDataQuality dataQuality,
        Instant generatedAt
) {
    public FirstJourneyAnalyticsSnapshot {
        stages = List.copyOf(stages);
    }
}
