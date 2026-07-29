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

    private final Map<String, PilotProgressState> pilots = new HashMap<>();
    private final Map<String, Map<String, PetProgressState>> pets = new HashMap<>();

    @Override
    public synchronized ProgressionState lockOrCreate(
            String userId,
            PilotDefinition pilot,
            PetDefinition pet,
            Instant observedAt
    ) {
        PilotProgressState pilotState = pilots.computeIfAbsent(
                userId,
                ignored -> PilotProgressState.initial(pilot)
        );
        PetProgressState petState = pets
                .computeIfAbsent(userId, ignored -> new HashMap<>())
                .computeIfAbsent(
                        pet.petId(),
                        ignored -> PetProgressState.initial(pet)
                );
        return new ProgressionState(
                pilotState,
                petState
        );
    }

    @Override
    public synchronized void save(
            String userId,
            String pilotId,
            String petId,
            ProgressionState state,
            Instant updatedAt
    ) {
        pilots.put(userId, state.pilot());
        pets.computeIfAbsent(userId, ignored -> new HashMap<>())
                .put(petId, state.pet());
    }
}
