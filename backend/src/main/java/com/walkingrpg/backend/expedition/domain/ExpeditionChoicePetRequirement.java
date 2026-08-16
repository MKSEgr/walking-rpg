package com.walkingrpg.backend.expedition.domain;

import java.util.Objects;

public record ExpeditionChoicePetRequirement(
        String petId,
        String petName,
        String lockedReason,
        int minimumEvolutionStage
) {
    public ExpeditionChoicePetRequirement {
        petId = requireText(petId, "petId");
        petName = requireText(petName, "petName");
        lockedReason = requireText(lockedReason, "lockedReason");
        if (minimumEvolutionStage < 0) {
            throw new IllegalArgumentException(
                    "minimumEvolutionStage не может быть отрицательной"
            );
        }
    }

    public ExpeditionChoicePetRequirement(
            String petId,
            String petName,
            String lockedReason
    ) {
        this(petId, petName, lockedReason, 0);
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
