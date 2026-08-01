package com.walkingrpg.backend.crafting.domain;

public record CraftingMaterialShortage(
        String itemId,
        long requiredQuantity,
        long availableQuantity
) {
}
