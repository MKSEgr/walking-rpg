package com.walkingrpg.backend.crafting.api;

import java.time.Instant;
import java.util.UUID;

public record CraftedUniqueItemResponse(
        UUID itemInstanceId,
        String itemId,
        String name,
        String description,
        long version,
        Instant craftedAt
) {
}
