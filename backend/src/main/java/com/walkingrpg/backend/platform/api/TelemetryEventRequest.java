package com.walkingrpg.backend.platform.api;

import java.time.Instant;
import java.util.Map;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record TelemetryEventRequest(
        @NotBlank @Size(max = 100) String eventName,
        Instant occurredAt,
        @Size(max = 64) Map<String, Object> attributes
) {
    public TelemetryEventRequest {
        attributes = attributes == null ? Map.of() : Map.copyOf(attributes);
    }
}
