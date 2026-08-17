package com.walkingrpg.backend.expedition.api;

import com.walkingrpg.backend.shared.validation.ExactJsonLongDeserializer;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;
import tools.jackson.databind.annotation.JsonDeserialize;

public record ExpeditionJourneyRequest(
        @JsonDeserialize(using = ExactJsonLongDeserializer.class)
        @NotNull @Positive Long expectedJourneyNumber,
        @NotBlank @Size(max = 128) String idempotencyKey
) {
}
