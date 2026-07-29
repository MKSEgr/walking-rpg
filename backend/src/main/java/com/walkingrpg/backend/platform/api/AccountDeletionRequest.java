package com.walkingrpg.backend.platform.api;

import jakarta.validation.constraints.NotBlank;

public record AccountDeletionRequest(
        @NotBlank String confirmation
) {
}
