package com.walkingrpg.backend.activity.api;

import java.time.Instant;

import com.walkingrpg.backend.shared.validation.ExactJsonLongDeserializer;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import tools.jackson.databind.annotation.JsonDeserialize;

public record ActivityBucketRequest(
        @NotNull Instant from,
        @NotNull Instant to,
        @JsonDeserialize(using = ExactJsonLongDeserializer.class)
        @NotNull @PositiveOrZero Long steps
) {
}
