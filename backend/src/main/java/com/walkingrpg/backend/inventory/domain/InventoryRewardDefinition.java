package com.walkingrpg.backend.inventory.domain;

import java.util.Objects;

public record InventoryRewardDefinition(
        InventoryItemDefinition item,
        long quantity
) {
    public InventoryRewardDefinition {
        Objects.requireNonNull(item, "item");
        if (quantity <= 0) {
            throw new IllegalArgumentException("quantity должна быть положительной");
        }
    }
}
