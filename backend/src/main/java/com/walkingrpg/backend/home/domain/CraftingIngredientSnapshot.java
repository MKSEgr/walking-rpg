package com.walkingrpg.backend.home.domain;

public record CraftingIngredientSnapshot(
        String itemId,
        String name,
        long requiredQuantity,
        long availableQuantity
) {
}
