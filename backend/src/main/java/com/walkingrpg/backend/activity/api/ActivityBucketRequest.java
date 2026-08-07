package com.walkingrpg.backend.activity.api;

import java.time.Instant;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;

public record ActivityBucketRequest(
        @NotNull Instant from,
        @NotNull Instant to,
        @NotNull @PositiveOrZero Long steps
) {
}
