package com.walkingrpg.backend.crafting.domain;

import java.util.Objects;

import com.walkingrpg.backend.inventory.domain.InventoryItemDefinition;
import com.walkingrpg.backend.inventory.domain.InventoryItemKind;

public record CraftingIngredientDefinition(
        InventoryItemDefinition item,
        long quantity
) {
    public CraftingIngredientDefinition {
        Objects.requireNonNull(item, "item");
        if (item.kind() != InventoryItemKind.MATERIAL) {
            throw new IllegalArgumentException(
                    "Crafting ingredient должен быть material"
            );
        }
        if (quantity <= 0) {
            throw new IllegalArgumentException(
                    "Crafting ingredient quantity должна быть положительной"
            );
        }
    }
}
