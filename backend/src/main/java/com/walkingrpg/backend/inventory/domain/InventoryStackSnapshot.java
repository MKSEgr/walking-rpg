package com.walkingrpg.backend.inventory.domain;

public record InventoryStackSnapshot(
        String itemId,
        long quantity,
        long version
) {
    public InventoryStackSnapshot {
        if (itemId == null || itemId.isBlank()) {
            throw new IllegalArgumentException("itemId обязателен");
        }
        itemId = itemId.trim();
        if (quantity < 0) {
            throw new IllegalArgumentException("quantity не может быть отрицательной");
        }
        if (version < 0) {
            throw new IllegalArgumentException("version не может быть отрицательной");
        }
    }
}
