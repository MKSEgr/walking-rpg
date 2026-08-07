package com.walkingrpg.backend.activity.api;

import java.time.LocalDate;
import java.util.List;

import com.walkingrpg.backend.shared.validation.ExactJsonLongDeserializer;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;
import tools.jackson.databind.annotation.JsonDeserialize;

public record ActivitySyncRequest(
        @NotNull LocalDate localDate,
        @NotBlank @Size(max = 64) String timeZone,
        @JsonDeserialize(using = ExactJsonLongDeserializer.class)
        @NotNull @PositiveOrZero Long authoritativeTotal,
        @Size(max = 96) List<@Valid ActivityBucketRequest> buckets,
        @Size(max = 512) String syncCursor,
        @NotBlank @Size(max = 128) String idempotencyKey,
        @Size(max = 4096) String attestation
) {
    public ActivitySyncRequest {
        buckets = buckets == null ? List.of() : List.copyOf(buckets);
    }
}
