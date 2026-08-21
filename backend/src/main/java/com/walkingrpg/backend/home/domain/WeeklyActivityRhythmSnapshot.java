package com.walkingrpg.backend.home.domain;

import java.util.List;
import java.util.Objects;

import com.walkingrpg.backend.goal.domain.WeeklyActivityRhythm;

public record WeeklyActivityRhythmSnapshot(
        int activeDays,
        int windowDays,
        int targetActiveDays,
        boolean targetReached,
        List<WeeklyActivityDaySnapshot> days
) {
    public WeeklyActivityRhythmSnapshot {
        days = List.copyOf(days);
    }

    public static WeeklyActivityRhythmSnapshot from(
            WeeklyActivityRhythm rhythm
    ) {
        WeeklyActivityRhythm value = Objects.requireNonNull(rhythm, "rhythm");
        return new WeeklyActivityRhythmSnapshot(
                value.activeDays(),
                value.windowDays(),
                value.targetActiveDays(),
                value.targetReached(),
                value.days().stream()
                        .map(WeeklyActivityDaySnapshot::from)
                        .toList()
        );
    }
}
