package com.walkingrpg.backend.progression.application;

import java.time.Instant;

import com.walkingrpg.backend.progression.domain.ProgressionRewardResult;
import com.walkingrpg.backend.progression.infrastructure.InMemoryProgressionRepository;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

class ProgressionServiceTest {

    private final ProgressionService service = new ProgressionService(
            new InMemoryProgressionRepository(),
            new StarterProgressionContent()
    );

    @Test
    void shouldPersistPilotExperienceAndPetBondAcrossRewards() {
        ProgressionRewardResult first = service.rewardEvent(
                "user-1",
                40,
                5,
                Instant.parse("2026-07-26T06:00:00Z")
        );
        ProgressionRewardResult second = service.rewardEvent(
                "user-1",
                20,
                15,
                Instant.parse("2026-07-26T06:05:00Z")
        );

        assertEquals(60, first.pilot().currentExperience());
        assertEquals(15, first.pet().bond());
        assertEquals(1, first.pilot().version());
        assertEquals(1, first.pet().version());
        assertEquals(80, second.pilot().currentExperience());
        assertEquals(30, second.pet().bond());
        assertEquals(2, second.pilot().version());
        assertEquals(2, second.pet().version());
    }

    @Test
    void shouldLevelPilotWhenRewardCrossesThreshold() {
        ProgressionRewardResult result = service.rewardEvent(
                "level-user",
                100,
                1,
                Instant.parse("2026-07-26T06:00:00Z")
        );

        assertEquals(2, result.pilot().level());
        assertEquals(20, result.pilot().currentExperience());
        assertEquals(150, result.pilot().nextLevelExperience());
    }
}
