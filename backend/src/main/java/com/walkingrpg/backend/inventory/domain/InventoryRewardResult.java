package com.walkingrpg.backend.inventory.domain;

import java.util.Objects;

public record InventoryRewardResult(
        InventoryItemDefinition item,
        long quantityGained,
        long quantityAfter,
        long version
) {
    public InventoryRewardResult {
        Objects.requireNonNull(item, "item");
        if (quantityGained <= 0) {
            throw new IllegalArgumentException("quantityGained должна быть положительной");
        }
        if (quantityAfter < quantityGained) {
            throw new IllegalArgumentException("quantityAfter меньше начисления");
        }
        if (version <= 0) {
            throw new IllegalArgumentException("version должна быть положительной");
        }
    }
}
