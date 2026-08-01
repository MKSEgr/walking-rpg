package com.walkingrpg.backend.crafting.api;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CraftingRequest(
        @NotBlank
        @Size(max = 128)
        String idempotencyKey
) {
}
