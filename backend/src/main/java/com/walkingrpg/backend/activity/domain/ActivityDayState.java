package com.walkingrpg.backend.activity.domain;

public record ActivityDayState(
        long acceptedTotal,
        long stateVersion
) {
    public static ActivityDayState initial() {
        return new ActivityDayState(0, 0);
    }
}
