package com.walkingrpg.backend.crafting.domain;

import java.time.Instant;
import java.util.UUID;

public record CraftedUniqueItemResult(
        UUID itemInstanceId,
        String itemId,
        String name,
        String description,
        long version,
        Instant craftedAt
) {
    public CraftedUniqueItemResult {
        if (itemInstanceId == null
                || itemId == null
                || itemId.isBlank()
                || name == null
                || name.isBlank()
                || description == null
                || description.isBlank()
                || craftedAt == null) {
            throw new IllegalArgumentException("Crafted unique item неполный");
        }
        if (version <= 0) {
            throw new IllegalArgumentException(
                    "Crafted unique item version должна быть положительной"
            );
        }
    }
}
