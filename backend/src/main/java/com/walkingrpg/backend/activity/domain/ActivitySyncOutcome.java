package com.walkingrpg.backend.activity.domain;

import java.util.Objects;

public record ActivitySyncOutcome(
        ActivitySyncResult activity,
        long energyBalanceAfter,
        long economyVersion
) {
    public ActivitySyncOutcome {
        Objects.requireNonNull(activity, "activity");
        if (energyBalanceAfter < 0) {
            throw new IllegalArgumentException("energyBalanceAfter не может быть отрицательным");
        }
        if (economyVersion < 0) {
            throw new IllegalArgumentException("economyVersion не может быть отрицательной");
        }
    }
}
