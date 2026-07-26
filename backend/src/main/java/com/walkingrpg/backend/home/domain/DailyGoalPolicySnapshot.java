package com.walkingrpg.backend.home.domain;

import java.math.BigDecimal;

import com.walkingrpg.backend.goal.domain.DailyGoal;
import com.walkingrpg.backend.goal.domain.DailyGoalSource;

public record DailyGoalPolicySnapshot(
        String policyVersion,
        DailyGoalSource source,
        BigDecimal baselineSteps,
        int sampleDays,
        int lookbackDays,
        int minimumSampleDays,
        long defaultGoal,
        int growthPercent,
        long roundingStep,
        long minimumGoal,
        long maximumGoal
) {
    public static DailyGoalPolicySnapshot from(DailyGoal goal) {
        return new DailyGoalPolicySnapshot(
                goal.policyVersion(),
                goal.source(),
                goal.baselineSteps(),
                goal.sampleDays(),
                goal.lookbackDays(),
                goal.minimumSampleDays(),
                goal.defaultGoal(),
                goal.growthPercent(),
                goal.roundingStep(),
                goal.minimumGoal(),
                goal.maximumGoal()
        );
    }
}
