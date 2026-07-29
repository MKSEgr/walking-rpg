package com.walkingrpg.backend.platform.analytics;

public record FirstJourneyDataQuality(
        long authoritativeMilestoneRecords,
        long backfilledMilestoneRecords
) {
}
