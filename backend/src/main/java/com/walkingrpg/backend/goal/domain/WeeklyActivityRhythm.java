package com.walkingrpg.backend.goal.domain;

import java.time.LocalDate;
import java.util.List;

public record WeeklyActivityRhythm(
        int activeDays,
        int windowDays,
        int targetActiveDays,
        List<WeeklyActivityDay> days
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
        days = List.copyOf(days);
        if (days.size() != windowDays) {
            throw new IllegalArgumentException(
                    "days должен полностью покрывать окно"
            );
        }
        int countedActiveDays = 0;
        LocalDate previousDate = null;
        for (WeeklyActivityDay day : days) {
            if (previousDate != null
                    && !day.localDate().equals(previousDate.plusDays(1))) {
                throw new IllegalArgumentException(
                        "days должен быть последовательным"
                );
            }
            if (day.active()) {
                countedActiveDays += 1;
            }
            previousDate = day.localDate();
        }
        if (countedActiveDays != activeDays) {
            throw new IllegalArgumentException(
                    "activeDays должен соответствовать days"
            );
        }
    }

    public boolean targetReached() {
        return activeDays >= targetActiveDays;
    }
}
