package com.walkingrpg.backend.progression.application;

import java.time.Instant;

import com.walkingrpg.backend.progression.domain.PetDefinition;
import com.walkingrpg.backend.progression.domain.PetProgressState;
import com.walkingrpg.backend.progression.domain.PilotProgressState;
import com.walkingrpg.backend.progression.domain.ProgressionRewardResult;
import com.walkingrpg.backend.progression.domain.ProgressionState;
import com.walkingrpg.backend.progression.infrastructure.ProgressionRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ProgressionService {

    private final ProgressionRepository repository;
    private final StarterProgressionContent content;
    private final ActivePetProvider activePetProvider;

    @Autowired
    public ProgressionService(
            ProgressionRepository repository,
            StarterProgressionContent content,
            ActivePetProvider activePetProvider
    ) {
        this.repository = repository;
        this.content = content;
        this.activePetProvider = activePetProvider;
    }

    public ProgressionService(
            ProgressionRepository repository,
            StarterProgressionContent content
    ) {
        this(
                repository,
                content,
                ignored -> new ActivePetSelection(
                        StarterProgressionContent.PET_ID,
                        content.pet().initialLevel(),
                        content.pet().initialBond()
                )
        );
    }

    @Transactional
    public ProgressionRewardResult rewardEvent(
            String userId,
            int pilotExperienceGained,
            int petBondGained,
            Instant occurredAt
    ) {
        if (pilotExperienceGained < 0 || petBondGained < 0
                || (pilotExperienceGained == 0 && petBondGained == 0)) {
            throw new IllegalArgumentException("Событие должно выдать положительную награду");
        }

        ActivePetSelection activePet = activePetProvider.activePetFor(userId);
        PetDefinition petDefinition = content.requirePet(activePet.petId());
        ProgressionState current = repository.lockOrCreate(
                userId,
                content.pilot(),
                petDefinition,
                occurredAt
        );
        PilotProgressState pilot = current.pilot().reward(pilotExperienceGained);
        PetProgressState pet = new PetProgressState(
                Math.max(current.pet().level(), activePet.level()),
                Math.max(current.pet().bond(), activePet.bond()),
                current.pet().version()
        ).reward(petBondGained);
        ProgressionState updated = new ProgressionState(pilot, pet);
        repository.save(
                userId,
                content.pilot().pilotId(),
                petDefinition.petId(),
                updated,
                occurredAt
        );

        return new ProgressionRewardResult(
                content.pilot(),
                pilot,
                pilotExperienceGained,
                petDefinition,
                pet,
                petBondGained
        );
    }

    @Transactional
    public PetProgressState synchronizeAndReward(
            String userId,
            String petId,
            int minimumLevel,
            int minimumBond,
            int bondGained,
            Instant occurredAt
    ) {
        if (minimumLevel <= 0 || minimumBond < 0 || bondGained < 0) {
            throw new IllegalArgumentException("Pet progression не может быть отрицательным");
        }
        PetDefinition petDefinition = content.requirePet(petId);
        ProgressionState current = repository.lockOrCreate(
                userId,
                content.pilot(),
                petDefinition,
                occurredAt
        );
        int synchronizedLevel = Math.max(current.pet().level(), minimumLevel);
        int synchronizedBond = Math.addExact(
                Math.max(current.pet().bond(), minimumBond),
                bondGained
        );
        if (synchronizedLevel == current.pet().level()
                && synchronizedBond == current.pet().bond()) {
            return current.pet();
        }

        PetProgressState pet = new PetProgressState(
                synchronizedLevel,
                synchronizedBond,
                current.pet().version() + 1
        );
        repository.save(
                userId,
                content.pilot().pilotId(),
                petId,
                new ProgressionState(current.pilot(), pet),
                occurredAt
        );
        return pet;
    }
}
