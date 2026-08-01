package com.walkingrpg.backend.platform.analytics;

import java.util.List;

public record CompassJourneyFunnel(
        CompassJourneyFunnelId funnel,
        CompassJourneyStage startStage,
        CompassJourneyStageSource startSource,
        long startedUsers,
        long notStartedUsers,
        double startRate,
        List<CompassJourneyStageMetric> stages
) {
    public CompassJourneyFunnel {
        stages = List.copyOf(stages);
    }
}
