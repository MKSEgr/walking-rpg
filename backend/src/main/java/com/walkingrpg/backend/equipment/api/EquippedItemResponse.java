package com.walkingrpg.backend.equipment.api;

import java.time.Instant;
import java.util.UUID;

public record EquippedItemResponse(
        UUID itemInstanceId,
        String itemId,
        String name,
        String description,
        Instant equippedAt
) {
}
