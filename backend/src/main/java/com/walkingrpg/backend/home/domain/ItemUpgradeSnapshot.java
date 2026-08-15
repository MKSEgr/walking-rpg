package com.walkingrpg.backend.home.domain;

import java.util.List;

public record ItemUpgradeSnapshot(
        String upgradeId,
        String upgradeVersion,
        String name,
        String description,
        String status,
        String targetItemId,
        String targetItemName,
        long requiredLevel,
        long resultingLevel,
        String initialRarity,
        String resultingRarity,
        List<ItemUpgradeIngredientSnapshot> ingredients
) {
    public ItemUpgradeSnapshot {
        ingredients = List.copyOf(ingredients);
    }
}
