package com.walkingrpg.backend.itemupgrade.api;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record ItemUpgradeRequest(
        @NotBlank
        @Size(max = 128)
        String idempotencyKey
) {
}
