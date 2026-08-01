package com.walkingrpg.backend.crafting.application;

public class CraftingRecipeNotFoundException extends RuntimeException {

    private final String recipeId;

    public CraftingRecipeNotFoundException(String recipeId) {
        super("Crafting recipe не найдена: " + recipeId);
        this.recipeId = recipeId;
    }

    public String recipeId() {
        return recipeId;
    }
}
