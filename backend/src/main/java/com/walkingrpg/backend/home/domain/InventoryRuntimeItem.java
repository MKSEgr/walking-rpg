package com.walkingrpg.backend.home.domain;

public record InventoryRuntimeItem(
        String itemId,
        long quantity,
        long version
) {
    public InventoryRuntimeItem {
        if (itemId == null || itemId.isBlank()) {
            throw new IllegalArgumentException("itemId обязателен");
        }
        itemId = itemId.trim();
        if (quantity <= 0) {
            throw new IllegalArgumentException("quantity должна быть положительной");
        }
        if (version <= 0) {
            throw new IllegalArgumentException("version должна быть положительной");
        }
    }
}
