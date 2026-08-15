package com.walkingrpg.backend.home.domain;

public record ItemUpgradeIngredientSnapshot(
        String itemId,
        String name,
        long requiredQuantity,
        long availableQuantity
) {
}
