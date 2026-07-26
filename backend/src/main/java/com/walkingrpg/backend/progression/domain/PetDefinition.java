package com.walkingrpg.backend.progression.domain;

import java.util.Objects;

public record PetDefinition(
        String petId,
        String name,
        String species,
        int initialLevel,
        int initialBond,
        String trait
) {
    public PetDefinition {
        petId = requireText(petId, "petId");
        name = requireText(name, "name");
        species = requireText(species, "species");
        trait = requireText(trait, "trait");
        if (initialLevel <= 0) {
            throw new IllegalArgumentException("initialLevel должна быть положительной");
        }
        if (initialBond < 0) {
            throw new IllegalArgumentException("initialBond не может быть отрицательной");
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
