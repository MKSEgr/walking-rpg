package com.walkingrpg.backend.crafting.domain;

public record CraftingCommand(
        String userId,
        String recipeId,
        String idempotencyKey
) {
}
