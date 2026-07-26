package com.walkingrpg.backend.progression.domain;

import java.util.Objects;

public record ProgressionState(
        PilotProgressState pilot,
        PetProgressState pet
) {
    public ProgressionState {
        Objects.requireNonNull(pilot, "pilot");
        Objects.requireNonNull(pet, "pet");
    }
}
