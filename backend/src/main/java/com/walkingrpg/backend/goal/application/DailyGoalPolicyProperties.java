package com.walkingrpg.backend.goal.application;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "walking-rpg.daily-goal")
public record DailyGoalPolicyProperties(
        String policyVersion,
        int lookbackDays,
        int minimumSampleDays,
        long defaultGoal,
        long minimumGoal,
        long maximumGoal,
        int growthPercent,
        long roundingStep
) {
    public DailyGoalPolicyProperties {
        if (policyVersion == null || policyVersion.isBlank()) {
            throw new IllegalArgumentException("policyVersion обязателен");
        }
        policyVersion = policyVersion.trim();
        if (lookbackDays <= 0) {
            throw new IllegalArgumentException("lookbackDays должна быть положительной");
        }
        if (minimumSampleDays <= 0 || minimumSampleDays > lookbackDays) {
            throw new IllegalArgumentException(
                    "minimumSampleDays должна быть в диапазоне 1..lookbackDays"
            );
        }
        if (minimumGoal <= 0 || maximumGoal < minimumGoal) {
            throw new IllegalArgumentException("Диапазон daily goal некорректен");
        }
        if (defaultGoal < minimumGoal || defaultGoal > maximumGoal) {
            throw new IllegalArgumentException("defaultGoal находится вне диапазона");
        }
        if (growthPercent < 0 || growthPercent > 100) {
            throw new IllegalArgumentException("growthPercent должна быть в диапазоне 0..100");
        }
        if (roundingStep <= 0) {
            throw new IllegalArgumentException("roundingStep должна быть положительной");
        }
        if (minimumGoal % roundingStep != 0
                || maximumGoal % roundingStep != 0
                || defaultGoal % roundingStep != 0) {
            throw new IllegalArgumentException(
                    "minimumGoal, maximumGoal и defaultGoal должны быть кратны roundingStep"
            );
        }
    }
}
