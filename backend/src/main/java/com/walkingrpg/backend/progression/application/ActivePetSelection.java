package com.walkingrpg.backend.progression.application;

public record ActivePetSelection(
        String petId,
        int level,
        int bond,
        int evolutionStage
) {
    public ActivePetSelection {
        if (petId == null || petId.isBlank()) {
            throw new IllegalArgumentException("petId обязателен");
        }
        if (level <= 0 || bond < 0 || evolutionStage < 0) {
            throw new IllegalArgumentException("Pet progression не может быть отрицательным");
        }
    }

    public ActivePetSelection(String petId, int level, int bond) {
        this(petId, level, bond, 0);
    }
}
