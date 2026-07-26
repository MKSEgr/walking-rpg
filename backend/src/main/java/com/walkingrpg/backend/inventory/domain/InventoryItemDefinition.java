package com.walkingrpg.backend.inventory.domain;

import java.util.Objects;

public record InventoryItemDefinition(
        String itemId,
        String name,
        String description
) {
    public InventoryItemDefinition {
        itemId = requireText(itemId, "itemId");
        name = requireText(name, "name");
        description = requireText(description, "description");
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
