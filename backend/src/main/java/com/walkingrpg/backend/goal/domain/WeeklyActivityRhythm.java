package com.walkingrpg.backend.goal.domain;

public record WeeklyActivityRhythm(
        int activeDays,
        int windowDays,
        int targetActiveDays
) {
    public WeeklyActivityRhythm {
        if (windowDays <= 0) {
            throw new IllegalArgumentException("windowDays должен быть положительным");
        }
        if (targetActiveDays <= 0 || targetActiveDays > windowDays) {
            throw new IllegalArgumentException(
                    "targetActiveDays должен входить в окно"
            );
        }
        if (activeDays < 0 || activeDays > windowDays) {
            throw new IllegalArgumentException(
                    "activeDays должен входить в окно"
            );
        }
    }

    public boolean targetReached() {
        return activeDays >= targetActiveDays;
    }
}
