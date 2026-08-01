package com.walkingrpg.backend.inventory.domain;

import java.util.Objects;

public record InventoryItemDefinition(
        String itemId,
        String name,
        String description,
        InventoryItemKind kind
) {
    public InventoryItemDefinition {
        itemId = requireText(itemId, "itemId");
        name = requireText(name, "name");
        description = requireText(description, "description");
        Objects.requireNonNull(kind, "kind");
    }

    public InventoryItemDefinition(
            String itemId,
            String name,
            String description
    ) {
        this(itemId, name, description, InventoryItemKind.MATERIAL);
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
