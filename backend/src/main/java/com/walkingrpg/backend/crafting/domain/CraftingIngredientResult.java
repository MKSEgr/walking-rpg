package com.walkingrpg.backend.crafting.domain;

public record CraftingIngredientResult(
        String itemId,
        String name,
        long quantityConsumed,
        long quantityAfter,
        long version
) {
    public CraftingIngredientResult {
        if (itemId == null || itemId.isBlank() || name == null || name.isBlank()) {
            throw new IllegalArgumentException("Crafting ingredient result неполный");
        }
        if (quantityConsumed <= 0 || quantityAfter < 0 || version <= 0) {
            throw new IllegalArgumentException(
                    "Crafting ingredient result содержит некорректные значения"
            );
        }
    }
}
