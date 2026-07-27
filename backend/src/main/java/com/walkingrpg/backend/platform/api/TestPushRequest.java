package com.walkingrpg.backend.platform.api;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record TestPushRequest(
        @NotBlank @Size(max = 128) String userId,
        @NotBlank @Size(max = 120) String title,
        @NotBlank @Size(max = 500) String body
) {
}
