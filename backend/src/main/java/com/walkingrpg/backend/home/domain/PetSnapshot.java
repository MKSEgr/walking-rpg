package com.walkingrpg.backend.home.domain;

public record PetSnapshot(
        String petId,
        String name,
        String species,
        int level,
        int bond,
        int evolutionStage,
        String trait
) {
}
