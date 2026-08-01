package com.walkingrpg.backend.platform.analytics;

public record CompassJourneyDataQuality(
        long clientReportedStageRecords,
        long authoritativeStageRecords,
        long outOfOrderPairs,
        long craftingTargetsWithoutStartUsers,
        long routeTargetsWithoutStartUsers
) {
}
