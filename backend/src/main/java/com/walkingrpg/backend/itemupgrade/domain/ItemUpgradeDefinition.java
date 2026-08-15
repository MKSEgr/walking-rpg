package com.walkingrpg.backend.itemupgrade.domain;

import java.util.HashSet;
import java.util.List;
import java.util.Objects;
import java.util.Set;

import com.walkingrpg.backend.crafting.domain.CraftingIngredientDefinition;
import com.walkingrpg.backend.inventory.domain.InventoryItemDefinition;
import com.walkingrpg.backend.inventory.domain.InventoryItemKind;
import com.walkingrpg.backend.inventory.domain.UniqueItemRarity;

public record ItemUpgradeDefinition(
        String contentVersion,
        String upgradeId,
        String upgradeVersion,
        String name,
        String description,
        InventoryItemDefinition targetItem,
        long requiredLevel,
        long resultingLevel,
        UniqueItemRarity initialRarity,
        UniqueItemRarity resultingRarity,
        List<CraftingIngredientDefinition> ingredients
) {
    public ItemUpgradeDefinition {
        contentVersion = requireText(contentVersion, "contentVersion");
        upgradeId = requireText(upgradeId, "upgradeId");
        upgradeVersion = requireText(upgradeVersion, "upgradeVersion");
        name = requireText(name, "name");
        description = requireText(description, "description");
        Objects.requireNonNull(targetItem, "targetItem");
        Objects.requireNonNull(initialRarity, "initialRarity");
        Objects.requireNonNull(resultingRarity, "resultingRarity");
        if (targetItem.kind() != InventoryItemKind.UNIQUE) {
            throw new IllegalArgumentException(
                    "Item upgrade должен ссылаться на unique item"
            );
        }
        if (requiredLevel <= 0 || resultingLevel != requiredLevel + 1) {
            throw new IllegalArgumentException(
                    "Item upgrade должен повышать уровень ровно на один"
            );
        }
        if (resultingRarity.ordinal() <= initialRarity.ordinal()) {
            throw new IllegalArgumentException(
                    "Item upgrade должен повышать rarity"
            );
        }
        ingredients = ingredients == null ? List.of() : List.copyOf(ingredients);
        if (ingredients.isEmpty()) {
            throw new IllegalArgumentException(
                    "Item upgrade должен содержать ingredients"
            );
        }
        Set<String> itemIds = new HashSet<>();
        for (CraftingIngredientDefinition ingredient : ingredients) {
            if (!itemIds.add(ingredient.item().itemId())) {
                throw new IllegalArgumentException(
                        "Item upgrade содержит повторяющийся ingredient"
                );
            }
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
