package com.walkingrpg.backend.inventory.domain;

import java.time.Instant;
import java.util.Objects;

public record InventoryReward(
        String userId,
        String itemId,
        long quantity,
        String reasonCode,
        String sourceType,
        String sourceKey,
        Instant occurredAt
) {
    public InventoryReward {
        userId = requireText(userId, "userId", 128);
        itemId = requireText(itemId, "itemId", 64);
        if (quantity <= 0) {
            throw new IllegalArgumentException("quantity должна быть положительной");
        }
        reasonCode = requireText(reasonCode, "reasonCode", 64);
        sourceType = requireText(sourceType, "sourceType", 64);
        sourceKey = requireText(sourceKey, "sourceKey", 300);
        Objects.requireNonNull(occurredAt, "occurredAt");
    }

    private static String requireText(String value, String field, int maxLength) {
        Objects.requireNonNull(value, field);
        String normalized = value.trim();
        if (normalized.isEmpty()) {
            throw new IllegalArgumentException(field + " обязателен");
        }
        if (normalized.length() > maxLength) {
            throw new IllegalArgumentException(field + " превышает " + maxLength + " символов");
        }
        return normalized;
    }
}
