package com.walkingrpg.backend.crafting.domain;

import java.util.HashSet;
import java.util.List;
import java.util.Objects;
import java.util.Set;

import com.walkingrpg.backend.inventory.domain.InventoryItemDefinition;
import com.walkingrpg.backend.inventory.domain.InventoryItemKind;

public record CraftingRecipeDefinition(
        String contentVersion,
        String recipeId,
        String recipeVersion,
        String name,
        String description,
        List<CraftingIngredientDefinition> ingredients,
        InventoryItemDefinition resultItem
) {
    public CraftingRecipeDefinition {
        contentVersion = requireText(contentVersion, "contentVersion");
        recipeId = requireText(recipeId, "recipeId");
        recipeVersion = requireText(recipeVersion, "recipeVersion");
        name = requireText(name, "name");
        description = requireText(description, "description");
        ingredients = ingredients == null ? List.of() : List.copyOf(ingredients);
        if (ingredients.isEmpty()) {
            throw new IllegalArgumentException(
                    "Crafting recipe должна содержать ingredients"
            );
        }
        Objects.requireNonNull(resultItem, "resultItem");
        if (resultItem.kind() != InventoryItemKind.UNIQUE) {
            throw new IllegalArgumentException(
                    "Crafting result должен быть unique item"
            );
        }
        Set<String> itemIds = new HashSet<>();
        for (CraftingIngredientDefinition ingredient : ingredients) {
            if (!itemIds.add(ingredient.item().itemId())) {
                throw new IllegalArgumentException(
                        "Crafting recipe содержит повторяющийся ingredient"
                );
            }
        }
        if (itemIds.contains(resultItem.itemId())) {
            throw new IllegalArgumentException(
                    "Crafting result не может быть ingredient"
            );
        }
    }

    private static String requireText(String value, String field) {
        Objects.requireNonNull(value, field);
        String normalized = value.trim();
        if (normalized.isEmpty()) {
            throw new IllegalArgumentException(field + " обязателен");
        }
        return normalized;
    }
}
