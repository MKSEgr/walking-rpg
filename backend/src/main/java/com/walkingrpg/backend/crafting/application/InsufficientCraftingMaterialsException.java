package com.walkingrpg.backend.crafting.application;

import java.util.List;

import com.walkingrpg.backend.crafting.domain.CraftingMaterialShortage;

public class InsufficientCraftingMaterialsException extends RuntimeException {

    private final List<CraftingMaterialShortage> shortages;

    public InsufficientCraftingMaterialsException(
            List<CraftingMaterialShortage> shortages
    ) {
        super("Недостаточно материалов для crafting recipe");
        this.shortages = List.copyOf(shortages);
    }

    public List<CraftingMaterialShortage> shortages() {
        return shortages;
    }
}
