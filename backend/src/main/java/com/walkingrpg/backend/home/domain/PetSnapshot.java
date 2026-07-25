package com.walkingrpg.backend.home.domain;

public record PetSnapshot(
        String name,
        String species,
        int level,
        int bond,
        String trait
) {
}
