package com.walkingrpg.backend.home.domain;

import java.time.LocalDate;
import java.util.Objects;

public record HomeQuery(
        String userId,
        LocalDate localDate
) {
    public HomeQuery {
        Objects.requireNonNull(userId, "userId");
        Objects.requireNonNull(localDate, "localDate");
    }
}
