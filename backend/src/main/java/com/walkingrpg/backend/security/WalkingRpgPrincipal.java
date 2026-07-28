package com.walkingrpg.backend.security;

import java.util.Objects;

public record WalkingRpgPrincipal(
        String userId,
        String actor,
        String deviceId
) {

    public WalkingRpgPrincipal {
        userId = requireText(userId, "userId");
        actor = requireText(actor, "actor");
        deviceId = normalizeOptional(deviceId);
    }

    private static String requireText(String value, String field) {
        Objects.requireNonNull(value, field);
        String normalized = value.trim();
        if (normalized.isEmpty()) {
            throw new IllegalArgumentException(field + " must not be blank");
        }
        return normalized;
    }

    private static String normalizeOptional(String value) {
        if (value == null) {
            return null;
        }
        String normalized = value.trim();
        return normalized.isEmpty() ? null : normalized;
    }
}
