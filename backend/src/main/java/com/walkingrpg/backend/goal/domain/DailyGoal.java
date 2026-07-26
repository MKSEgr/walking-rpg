package com.walkingrpg.backend.goal.domain;

import java.math.BigDecimal;
import java.util.Objects;

public record DailyGoal(
        long steps,
        DailyGoalSource source,
        BigDecimal baselineSteps,
        int sampleDays,
        int lookbackDays,
        int minimumSampleDays,
        long defaultGoal,
        int growthPercent,
        long roundingStep,
        long minimumGoal,
        long maximumGoal,
        String policyVersion
) {
    public DailyGoal {
        if (steps <= 0) {
            throw new IllegalArgumentException("Daily goal должна быть положительной");
        }
        Objects.requireNonNull(source, "source");
        if (baselineSteps != null && baselineSteps.signum() <= 0) {
            throw new IllegalArgumentException("baselineSteps должна быть положительной");
        }
        if (sampleDays < 0 || lookbackDays <= 0 || minimumSampleDays <= 0) {
            throw new IllegalArgumentException("Параметры выборки daily goal некорректны");
        }
        if (minimumSampleDays > lookbackDays || sampleDays > lookbackDays) {
            throw new IllegalArgumentException("Количество дней превышает окно daily goal");
        }
        if (defaultGoal <= 0 || growthPercent < 0 || roundingStep <= 0
                || minimumGoal <= 0 || maximumGoal < minimumGoal) {
            throw new IllegalArgumentException("Параметры расчёта daily goal некорректны");
        }
        if (defaultGoal < minimumGoal || defaultGoal > maximumGoal) {
            throw new IllegalArgumentException("defaultGoal находится вне разрешённого диапазона");
        }
        if (steps < minimumGoal || steps > maximumGoal) {
            throw new IllegalArgumentException("Daily goal находится вне разрешённого диапазона");
        }
        if (steps % roundingStep != 0 || defaultGoal % roundingStep != 0) {
            throw new IllegalArgumentException(
                    "Daily goal и defaultGoal должны быть кратны roundingStep"
            );
        }
        policyVersion = requireText(policyVersion, "policyVersion");

        if (source == DailyGoalSource.DEFAULT) {
            if (baselineSteps != null) {
                throw new IllegalArgumentException("DEFAULT goal не должна содержать baseline");
            }
            if (sampleDays >= minimumSampleDays) {
                throw new IllegalArgumentException(
                        "DEFAULT goal допустима только до накопления minimumSampleDays"
                );
            }
            if (steps != defaultGoal) {
                throw new IllegalArgumentException("DEFAULT goal должна совпадать с defaultGoal");
            }
        }
        if (source == DailyGoalSource.ADAPTIVE) {
            if (baselineSteps == null) {
                throw new IllegalArgumentException("ADAPTIVE goal должна содержать baseline");
            }
            if (sampleDays < minimumSampleDays) {
                throw new IllegalArgumentException(
                        "ADAPTIVE goal требует minimumSampleDays истории"
                );
            }
        }
    }

    private static String requireText(String value, String field) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException(field + " обязателен");
        }
        return value.trim();
    }
}
