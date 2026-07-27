package com.walkingrpg.backend.platform.domain;

public record PlatformCommandScope(
        String userId,
        String commandType,
        String idempotencyKey
) {
    public PlatformCommandScope {
        userId = requireText(userId, "userId", 128);
        commandType = requireText(commandType, "commandType", 64);
        idempotencyKey = requireText(idempotencyKey, "idempotencyKey", 128);
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
