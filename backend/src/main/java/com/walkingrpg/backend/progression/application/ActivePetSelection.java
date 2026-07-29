package com.walkingrpg.backend.progression.application;

public record ActivePetSelection(
        String petId,
        int level,
        int bond
) {
    public ActivePetSelection {
        if (petId == null || petId.isBlank()) {
            throw new IllegalArgumentException("petId обязателен");
        }
        if (level <= 0 || bond < 0) {
            throw new IllegalArgumentException("Pet progression не может быть отрицательным");
        }
    }
}
