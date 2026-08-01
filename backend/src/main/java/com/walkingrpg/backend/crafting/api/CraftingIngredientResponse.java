package com.walkingrpg.backend.crafting.api;

public record CraftingIngredientResponse(
        String itemId,
        String name,
        long quantityConsumed,
        long quantityAfter,
        long version
) {
}
