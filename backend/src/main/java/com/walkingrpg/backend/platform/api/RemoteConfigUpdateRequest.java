package com.walkingrpg.backend.platform.api;

import java.util.Map;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record RemoteConfigUpdateRequest(
        @NotBlank @Size(max = 64) String version,
        @NotNull Map<String, Object> config
) {
    public RemoteConfigUpdateRequest {
        config = config == null ? Map.of() : Map.copyOf(config);
    }
}
