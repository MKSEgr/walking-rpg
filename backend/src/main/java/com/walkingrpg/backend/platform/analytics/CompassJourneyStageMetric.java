package com.walkingrpg.backend.platform.analytics;

public record CompassJourneyStageMetric(
        CompassJourneyStage stage,
        CompassJourneyStageSource source,
        long reachedUsers,
        long missingFromStartedUsers,
        long orderedUsers,
        long outOfOrderUsers,
        double conversionFromStarted,
        double orderedConversionFromStarted,
        Long medianSecondsFromStart,
        Long p90SecondsFromStart
) {
}
