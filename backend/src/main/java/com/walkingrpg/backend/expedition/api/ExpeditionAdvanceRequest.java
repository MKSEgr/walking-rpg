package com.walkingrpg.backend.expedition.api;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

public record ExpeditionAdvanceRequest(
        @Positive long energyToSpend,
        @NotBlank @Size(max = 128) String idempotencyKey
) {
}
