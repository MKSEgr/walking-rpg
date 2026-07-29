package com.walkingrpg.backend.progression.application;

import java.time.Instant;
import java.util.concurrent.atomic.AtomicReference;

import com.walkingrpg.backend.progression.domain.PetProgressState;
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

    @Test
    void shouldRewardSelectedPetAndKeepPetProgressIndependent() {
        AtomicReference<String> selectedPet = new AtomicReference<>("moss-v1");
        ProgressionService selectedPetService = new ProgressionService(
                new InMemoryProgressionRepository(),
                new StarterProgressionContent(),
                ignored -> new ActivePetSelection(selectedPet.get(), 1, 10)
        );

        ProgressionRewardResult mossFirst = selectedPetService.rewardEvent(
                "pet-owner",
                10,
                5,
                Instant.parse("2026-07-26T06:00:00Z")
        );
        selectedPet.set("spark-v1");
        ProgressionRewardResult spark = selectedPetService.rewardEvent(
                "pet-owner",
                10,
                7,
                Instant.parse("2026-07-26T06:05:00Z")
        );
        selectedPet.set("moss-v1");
        ProgressionRewardResult mossSecond = selectedPetService.rewardEvent(
                "pet-owner",
                10,
                3,
                Instant.parse("2026-07-26T06:10:00Z")
        );

        assertEquals("moss-v1", mossFirst.petDefinition().petId());
        assertEquals("Мох", mossFirst.petDefinition().name());
        assertEquals(15, mossFirst.pet().bond());
        assertEquals("spark-v1", spark.petDefinition().petId());
        assertEquals(17, spark.pet().bond());
        assertEquals(18, mossSecond.pet().bond());
        assertEquals(50, mossSecond.pilot().currentExperience());
    }

    @Test
    void shouldMergePlatformPetProgressBeforeNextEventReward() {
        InMemoryProgressionRepository repository = new InMemoryProgressionRepository();
        ProgressionService selectedPetService = new ProgressionService(
                repository,
                new StarterProgressionContent(),
                ignored -> new ActivePetSelection("moss-v1", 2, 54)
        );

        PetProgressState synchronizedPet = selectedPetService.synchronizeAndReward(
                "merged-pet-owner",
                "moss-v1",
                2,
                50,
                4,
                Instant.parse("2026-07-26T06:00:00Z")
        );
        ProgressionRewardResult event = selectedPetService.rewardEvent(
                "merged-pet-owner",
                10,
                5,
                Instant.parse("2026-07-26T06:05:00Z")
        );

        assertEquals(2, synchronizedPet.level());
        assertEquals(54, synchronizedPet.bond());
        assertEquals(2, event.pet().level());
        assertEquals(59, event.pet().bond());
    }
}
