package com.walkingrpg.backend.progression.infrastructure;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;

import com.walkingrpg.backend.progression.domain.PetDefinition;
import com.walkingrpg.backend.progression.domain.PetProgressState;
import com.walkingrpg.backend.progression.domain.PilotDefinition;
import com.walkingrpg.backend.progression.domain.PilotProgressState;
import com.walkingrpg.backend.progression.domain.ProgressionState;

public class InMemoryProgressionRepository implements ProgressionRepository {

    private final Map<String, ProgressionState> states = new HashMap<>();

    @Override
    public synchronized ProgressionState lockOrCreate(
            String userId,
            PilotDefinition pilot,
            PetDefinition pet,
            Instant observedAt
    ) {
        return states.computeIfAbsent(
                userId,
                ignored -> new ProgressionState(
                        PilotProgressState.initial(pilot),
                        PetProgressState.initial(pet)
                )
        );
    }

    @Override
    public synchronized void save(
            String userId,
            ProgressionState state,
            Instant updatedAt
    ) {
        states.put(userId, state);
    }
}
