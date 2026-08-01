package com.walkingrpg.backend.crafting.application;

public class CraftingStateConflictException extends RuntimeException {

    private final String recipeId;
    private final String itemId;

    public CraftingStateConflictException(String recipeId, String itemId) {
        super("Уникальный предмет по этой recipe уже создан");
        this.recipeId = recipeId;
        this.itemId = itemId;
    }

    public String recipeId() {
        return recipeId;
    }

    public String itemId() {
        return itemId;
    }
}
