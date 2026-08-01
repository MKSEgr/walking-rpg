package com.walkingrpg.backend.home.domain;

import java.util.List;

public record CraftingRecipeSnapshot(
        String recipeId,
        String recipeVersion,
        String name,
        String description,
        String status,
        List<CraftingIngredientSnapshot> ingredients,
        CraftingResultPreviewSnapshot result
) {
    public CraftingRecipeSnapshot {
        ingredients = List.copyOf(ingredients);
    }
}
