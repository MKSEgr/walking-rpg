package com.walkingrpg.backend.home.domain;

import java.util.UUID;

public record InventoryRuntimeItem(
        String itemId,
        long quantity,
        long version,
        UUID itemInstanceId,
        String equippedSlotId
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
        if (equippedSlotId != null && itemInstanceId == null) {
            throw new IllegalArgumentException(
                    "Material item не может быть экипирован"
            );
        }
    }

    public InventoryRuntimeItem(String itemId, long quantity, long version) {
        this(itemId, quantity, version, null, null);
    }
}
