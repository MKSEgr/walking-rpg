package com.walkingrpg.backend.expedition.api;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record EventResolutionRequest(
        @NotBlank @Size(max = 64) String choiceId,
        @NotBlank @Size(max = 128) String idempotencyKey
) {
}
