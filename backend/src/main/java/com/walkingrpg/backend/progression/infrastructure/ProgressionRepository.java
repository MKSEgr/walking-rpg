package com.walkingrpg.backend.progression.infrastructure;

import java.time.Instant;

import com.walkingrpg.backend.progression.domain.PetDefinition;
import com.walkingrpg.backend.progression.domain.PilotDefinition;
import com.walkingrpg.backend.progression.domain.ProgressionState;

public interface ProgressionRepository {

    ProgressionState lockOrCreate(
            String userId,
            PilotDefinition pilot,
            PetDefinition pet,
            Instant observedAt
    );

    void save(
            String userId,
            String pilotId,
            String petId,
            ProgressionState state,
            Instant updatedAt
    );
}
