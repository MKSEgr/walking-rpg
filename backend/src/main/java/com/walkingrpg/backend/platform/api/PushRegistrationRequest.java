package com.walkingrpg.backend.platform.api;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record PushRegistrationRequest(
        @NotBlank @Size(max = 128) String deviceId,
        @NotBlank @Size(max = 32) String platform,
        @NotBlank @Size(max = 32) String provider,
        @NotBlank @Size(max = 4096) String token
) {
}
