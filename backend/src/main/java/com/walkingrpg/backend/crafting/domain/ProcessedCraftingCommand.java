package com.walkingrpg.backend.crafting.domain;

public record ProcessedCraftingCommand(
        String requestFingerprint,
        CraftingResult result
) {
}
