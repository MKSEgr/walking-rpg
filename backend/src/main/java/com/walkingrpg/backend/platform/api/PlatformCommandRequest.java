package com.walkingrpg.backend.platform.api;

import java.util.Map;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record PlatformCommandRequest(
        @NotBlank @Size(max = 64) String commandType,
        @NotBlank @Size(max = 128) String idempotencyKey,
        @NotNull Map<String, Object> payload
) {
    public PlatformCommandRequest {
        payload = payload == null ? null : Map.copyOf(payload);
    }
}
