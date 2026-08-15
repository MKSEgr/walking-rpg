package com.walkingrpg.backend.itemupgrade.application;

import com.walkingrpg.backend.itemupgrade.api.ItemUpgradeRequest;
import com.walkingrpg.backend.itemupgrade.domain.ItemUpgradeCommand;
import org.springframework.stereotype.Component;

@Component
public class ItemUpgradeCommandFactory {

    public ItemUpgradeCommand create(
            String userId,
            String upgradeId,
            ItemUpgradeRequest request
    ) {
        return new ItemUpgradeCommand(
                requireText(userId, "userId", 128),
                requireText(upgradeId, "upgradeId", 64),
                requireText(request.idempotencyKey(), "idempotencyKey", 128)
        );
    }

    private String requireText(String value, String field, int maxLength) {
        if (value == null || value.isBlank()) {
            throw new ItemUpgradeValidationException(
                    field + " обязателен",
                    field
            );
        }
        String normalized = value.trim();
        if (normalized.length() > maxLength) {
            throw new ItemUpgradeValidationException(
                    field + " превышает " + maxLength + " символов",
                    field
            );
        }
        return normalized;
    }
}
