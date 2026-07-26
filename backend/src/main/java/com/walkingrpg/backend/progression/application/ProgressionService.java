package com.walkingrpg.backend.progression.application;

import java.time.Instant;

import com.walkingrpg.backend.progression.domain.PetProgressState;
import com.walkingrpg.backend.progression.domain.PilotProgressState;
import com.walkingrpg.backend.progression.domain.ProgressionRewardResult;
import com.walkingrpg.backend.progression.domain.ProgressionState;
import com.walkingrpg.backend.progression.infrastructure.ProgressionRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ProgressionService {

    private final ProgressionRepository repository;
    private final StarterProgressionContent content;

    public ProgressionService(
            ProgressionRepository repository,
            StarterProgressionContent content
    ) {
        this.repository = repository;
        this.content = content;
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

        ProgressionState current = repository.lockOrCreate(
                userId,
                content.pilot(),
                content.pet(),
                occurredAt
        );
        PilotProgressState pilot = current.pilot().reward(pilotExperienceGained);
        PetProgressState pet = current.pet().reward(petBondGained);
        ProgressionState updated = new ProgressionState(pilot, pet);
        repository.save(userId, updated, occurredAt);

        return new ProgressionRewardResult(
                content.pilot(),
                pilot,
                pilotExperienceGained,
                content.pet(),
                pet,
                petBondGained
        );
    }
}
