package com.walkingrpg.backend.equipment.domain;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

public record EquippedItemResult(
        UUID itemInstanceId,
        String itemId,
        String name,
        String description,
        Instant equippedAt
) {
    public EquippedItemResult {
        Objects.requireNonNull(itemInstanceId, "itemInstanceId");
        itemId = requireText(itemId, "itemId");
        name = requireText(name, "name");
        description = requireText(description, "description");
        Objects.requireNonNull(equippedAt, "equippedAt");
    }

    private static String requireText(String value, String field) {
        Objects.requireNonNull(value, field);
        String normalized = value.trim();
        if (normalized.isEmpty()) {
            throw new IllegalArgumentException(field + " обязателен");
        }
        return normalized;
    }
}
