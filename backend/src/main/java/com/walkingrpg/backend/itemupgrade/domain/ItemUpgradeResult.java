package com.walkingrpg.backend.itemupgrade.domain;

import java.time.Instant;
import java.util.List;

import com.walkingrpg.backend.crafting.domain.CraftingIngredientResult;

public record ItemUpgradeResult(
        String contentVersion,
        String upgradeId,
        String upgradeVersion,
        String upgradeName,
        List<CraftingIngredientResult> consumedIngredients,
        UpgradedUniqueItemResult upgradedItem,
        Instant serverTime
) {
    public ItemUpgradeResult {
        consumedIngredients = consumedIngredients == null
                ? List.of()
                : List.copyOf(consumedIngredients);
        if (consumedIngredients.isEmpty()
                || upgradedItem == null
                || serverTime == null) {
            throw new IllegalArgumentException("Item upgrade result неполный");
        }
    }
}
