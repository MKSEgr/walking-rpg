package com.walkingrpg.backend.platform.analytics;

public record FirstJourneyStageMetric(
        FirstJourneyMilestone milestone,
        long reachedUsers,
        long missingFromStartedUsers,
        long authoritativeReachedUsers,
        long timedUsers,
        double conversionFromStarted,
        double authoritativeConversionFromStarted,
        Long medianSecondsFromStart,
        Long p90SecondsFromStart
) {
}
