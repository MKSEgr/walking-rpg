package com.walkingrpg.backend.expedition.domain;

import java.util.Objects;

public record ExpeditionChoicePetRequirement(
        String petId,
        String petName,
        String lockedReason
) {
    public ExpeditionChoicePetRequirement {
        petId = requireText(petId, "petId");
        petName = requireText(petName, "petName");
        lockedReason = requireText(lockedReason, "lockedReason");
    }

    private static String requireText(String value, String field) {
        Objects.requireNonNull(value, field);
        String normalized = value.trim();
        if (normalized.isEmpty()) {
            throw new IllegalArgumentException(field + " обязателен");
        }
        return normalized;
    }
}
