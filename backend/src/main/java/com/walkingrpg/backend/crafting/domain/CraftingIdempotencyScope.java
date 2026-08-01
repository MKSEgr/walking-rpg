package com.walkingrpg.backend.crafting.domain;

public record CraftingIdempotencyScope(
        String userId,
        String recipeId,
        String idempotencyKey
) {
    public static CraftingIdempotencyScope from(CraftingCommand command) {
        return new CraftingIdempotencyScope(
                command.userId(),
                command.recipeId(),
                command.idempotencyKey()
        );
    }
}
