package com.walkingrpg.backend.goal.domain;

import java.time.LocalDate;
import java.util.Objects;

public record WeeklyActivityDay(
        LocalDate localDate,
        boolean active
) {
    public WeeklyActivityDay {
        Objects.requireNonNull(localDate, "localDate");
    }
}
