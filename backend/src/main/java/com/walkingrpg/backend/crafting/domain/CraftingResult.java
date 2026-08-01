package com.walkingrpg.backend.crafting.domain;

import java.time.Instant;
import java.util.List;

public record CraftingResult(
        String contentVersion,
        String recipeId,
        String recipeVersion,
        String recipeName,
        List<CraftingIngredientResult> consumedIngredients,
        CraftedUniqueItemResult craftedItem,
        Instant serverTime
) {
    public CraftingResult {
        consumedIngredients = consumedIngredients == null
                ? List.of()
                : List.copyOf(consumedIngredients);
        if (consumedIngredients.isEmpty()
                || craftedItem == null
                || serverTime == null) {
            throw new IllegalArgumentException("Crafting result неполный");
        }
    }
}
