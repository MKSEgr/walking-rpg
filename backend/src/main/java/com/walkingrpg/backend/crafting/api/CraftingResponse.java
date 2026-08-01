package com.walkingrpg.backend.crafting.api;

import java.time.Instant;
import java.util.List;

public record CraftingResponse(
        String contentVersion,
        String recipeId,
        String recipeVersion,
        String recipeName,
        List<CraftingIngredientResponse> consumedIngredients,
        CraftedUniqueItemResponse craftedItem,
        Instant serverTime
) {
    public CraftingResponse {
        consumedIngredients = List.copyOf(consumedIngredients);
    }
}
