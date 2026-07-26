package com.walkingrpg.backend.progression.domain;

import java.util.Objects;

public record ProgressionRewardResult(
        PilotDefinition pilotDefinition,
        PilotProgressState pilot,
        int pilotExperienceGained,
        PetDefinition petDefinition,
        PetProgressState pet,
        int petBondGained
) {
    public ProgressionRewardResult {
        Objects.requireNonNull(pilotDefinition, "pilotDefinition");
        Objects.requireNonNull(pilot, "pilot");
        Objects.requireNonNull(petDefinition, "petDefinition");
        Objects.requireNonNull(pet, "pet");
        if (pilotExperienceGained < 0 || petBondGained < 0) {
            throw new IllegalArgumentException("Награда progression не может быть отрицательной");
        }
    }
}
