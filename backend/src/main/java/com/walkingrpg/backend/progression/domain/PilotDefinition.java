package com.walkingrpg.backend.progression.domain;

import java.util.Objects;

public record PilotDefinition(
        String pilotId,
        String name,
        int initialLevel,
        int initialExperience,
        int nextLevelExperience,
        String specialization
) {
    public PilotDefinition {
        pilotId = requireText(pilotId, "pilotId");
        name = requireText(name, "name");
        specialization = requireText(specialization, "specialization");
        if (initialLevel <= 0) {
            throw new IllegalArgumentException("initialLevel должна быть положительной");
        }
        if (initialExperience < 0 || nextLevelExperience <= 0
                || initialExperience >= nextLevelExperience) {
            throw new IllegalArgumentException("Некорректный стартовый опыт пилота");
        }
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
