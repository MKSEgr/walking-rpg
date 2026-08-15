package com.walkingrpg.backend.itemupgrade.api;

public record ItemUpgradeIngredientResponse(
        String itemId,
        String name,
        long quantityConsumed,
        long quantityAfter,
        long version
) {
}
