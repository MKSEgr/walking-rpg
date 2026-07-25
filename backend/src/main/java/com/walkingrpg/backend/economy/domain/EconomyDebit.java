package com.walkingrpg.backend.economy.domain;

import java.time.Instant;
import java.util.Objects;

public record EconomyDebit(
        String userId,
        EconomyCurrency currency,
        long amount,
        String reasonCode,
        String sourceType,
        String sourceKey,
        Instant occurredAt
) {
    public EconomyDebit {
        userId = requireText(userId, "userId", 128);
        Objects.requireNonNull(currency, "currency");
        if (amount <= 0) {
            throw new IllegalArgumentException("Сумма debit должна быть положительной");
        }
        reasonCode = requireText(reasonCode, "reasonCode", 64);
        sourceType = requireText(sourceType, "sourceType", 64);
        sourceKey = requireText(sourceKey, "sourceKey", 300);
        Objects.requireNonNull(occurredAt, "occurredAt");
    }

    private static String requireText(String value, String field, int maxLength) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException(field + " обязателен");
        }
        String normalized = value.trim();
        if (normalized.length() > maxLength) {
            throw new IllegalArgumentException(field + " превышает " + maxLength + " символов");
        }
        return normalized;
    }
}
