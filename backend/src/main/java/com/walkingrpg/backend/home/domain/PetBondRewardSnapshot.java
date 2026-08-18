package com.walkingrpg.backend.home.domain;

public record PetBondRewardSnapshot(
        String petId,
        String petName,
        long bondGained
) {
    public PetBondRewardSnapshot {
        if (petId == null || petId.isBlank()) {
            throw new IllegalArgumentException("petId is required");
        }
        if (petName == null || petName.isBlank()) {
            throw new IllegalArgumentException("petName is required");
        }
        if (bondGained <= 0) {
            throw new IllegalArgumentException("bondGained must be positive");
        }
    }
}
