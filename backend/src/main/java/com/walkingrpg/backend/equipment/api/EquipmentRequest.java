package com.walkingrpg.backend.equipment.api;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record EquipmentRequest(
        @Size(max = 36)
        String itemInstanceId,
        @NotBlank
        @Size(max = 128)
        String idempotencyKey
) {
}
