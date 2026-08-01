package com.walkingrpg.backend.crafting.application;

import com.walkingrpg.backend.crafting.api.CraftingRequest;
import com.walkingrpg.backend.crafting.domain.CraftingCommand;
import org.springframework.stereotype.Component;

@Component
public class CraftingCommandFactory {

    public CraftingCommand create(
            String userId,
            String recipeId,
            CraftingRequest request
    ) {
        return new CraftingCommand(
                requireText(userId, "userId", 128),
                requireText(recipeId, "recipeId", 64),
                requireText(request.idempotencyKey(), "idempotencyKey", 128)
        );
    }

    private String requireText(String value, String field, int maxLength) {
        if (value == null || value.isBlank()) {
            throw new CraftingValidationException(
                    field + " обязателен",
                    field
            );
        }
        String normalized = value.trim();
        if (normalized.length() > maxLength) {
            throw new CraftingValidationException(
                    field + " превышает " + maxLength + " символов",
                    field
            );
        }
        return normalized;
    }
}
