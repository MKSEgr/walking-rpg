package com.walkingrpg.backend.equipment.domain;

import java.util.Objects;
import java.util.UUID;

public record UniqueInventoryItemReference(
        UUID itemInstanceId,
        String itemId
) {
    public UniqueInventoryItemReference {
        Objects.requireNonNull(itemInstanceId, "itemInstanceId");
        Objects.requireNonNull(itemId, "itemId");
        itemId = itemId.trim();
        if (itemId.isEmpty()) {
            throw new IllegalArgumentException("itemId обязателен");
        }
    }
}
