package com.walkingrpg.backend.home.domain;

import java.time.LocalDate;
import java.util.Objects;

import com.walkingrpg.backend.goal.domain.WeeklyActivityDay;

public record WeeklyActivityDaySnapshot(
        LocalDate localDate,
        boolean active
) {
    public WeeklyActivityDaySnapshot {
        Objects.requireNonNull(localDate, "localDate");
    }

    public static WeeklyActivityDaySnapshot from(WeeklyActivityDay day) {
        WeeklyActivityDay value = Objects.requireNonNull(day, "day");
        return new WeeklyActivityDaySnapshot(
                value.localDate(),
                value.active()
        );
    }
}
