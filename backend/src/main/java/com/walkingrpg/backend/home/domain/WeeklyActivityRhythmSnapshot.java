package com.walkingrpg.backend.home.domain;

import java.util.Objects;

import com.walkingrpg.backend.goal.domain.WeeklyActivityRhythm;

public record WeeklyActivityRhythmSnapshot(
        int activeDays,
        int windowDays,
        int targetActiveDays,
        boolean targetReached
) {
    public static WeeklyActivityRhythmSnapshot from(
            WeeklyActivityRhythm rhythm
    ) {
        WeeklyActivityRhythm value = Objects.requireNonNull(rhythm, "rhythm");
        return new WeeklyActivityRhythmSnapshot(
                value.activeDays(),
                value.windowDays(),
                value.targetActiveDays(),
                value.targetReached()
        );
    }
}
