package com.walkingrpg.backend.itemupgrade.api;

import java.time.Instant;
import java.util.List;

public record ItemUpgradeResponse(
        String contentVersion,
        String upgradeId,
        String upgradeVersion,
        String upgradeName,
        List<ItemUpgradeIngredientResponse> consumedIngredients,
        UpgradedUniqueItemResponse upgradedItem,
        Instant serverTime
) {
    public ItemUpgradeResponse {
        consumedIngredients = List.copyOf(consumedIngredients);
    }
}
