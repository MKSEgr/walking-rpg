package com.walkingrpg.backend.home.application;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;

import com.walkingrpg.backend.expedition.application.StarterExpeditionContent;
import com.walkingrpg.backend.expedition.domain.ProcessedEventResolution;
import com.walkingrpg.backend.goal.application.AdaptiveDailyGoalCalculator;
import com.walkingrpg.backend.goal.application.DailyGoalPolicyProperties;
import com.walkingrpg.backend.goal.application.DailyGoalService;
import com.walkingrpg.backend.home.api.HomeSnapshotResponse;
import com.walkingrpg.backend.home.domain.HomeQuery;
import com.walkingrpg.backend.home.domain.HomeRuntimeState;
import com.walkingrpg.backend.home.infrastructure.HomeReadRepository;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;

class HomeServiceTest {

    private static final Instant NOW = Instant.parse("2026-07-25T12:00:00Z");
    private static final Instant LAST_SYNC = Instant.parse("2026-07-25T11:55:00Z");

    @Test
    void shouldCombineRuntimeStateWithStarterContentAndEvent() {
        HomeReadRepository repository = repository(
                new HomeRuntimeState(
                        6_842,
                        3,
                        "Europe/Berlin",
                        LAST_SYNC,
                        38,
                        2,
                        30,
                        30,
                        "EVENT_READY",
                        1,
                        "outer-beacon",
                        "signal-source-v1"
                )
        );
        DailyGoalPolicyProperties goalProperties = goalProperties();
        HomeService service = new HomeService(
                repository,
                new StarterHomeContent(),
                new DailyGoalService(
                        (userId, fromInclusive, toExclusive) ->
                                List.of(2_000L, 3_000L, 4_000L),
                        new AdaptiveDailyGoalCalculator(goalProperties),
                        goalProperties
                ),
                new StarterExpeditionContent(),
                Clock.fixed(NOW, ZoneOffset.UTC)
        );

        HomeSnapshotResponse snapshot = service.getSnapshot(
                new HomeQuery("user-1", LocalDate.of(2026, 7, 25))
        );

        assertEquals(6_842, snapshot.dailySteps());
        assertEquals(3_250, snapshot.dailyGoal());
        assertEquals("ADAPTIVE", snapshot.dailyGoalPolicy().source().name());
        assertEquals(BigDecimal.valueOf(3_000), snapshot.dailyGoalPolicy().baselineSteps());
        assertEquals(3, snapshot.dailyGoalPolicy().sampleDays());
        assertEquals(6_000, snapshot.dailyGoalPolicy().defaultGoal());
        assertEquals(38, snapshot.availableEnergy());
        assertEquals(3, snapshot.activityStateVersion());
        assertEquals(2, snapshot.economyVersion());
        assertEquals("Europe/Berlin", snapshot.timeZone());
        assertEquals(LAST_SYNC, snapshot.lastActivitySyncAt());
        assertEquals(NOW, snapshot.serverTime());
        assertEquals("Навигатор", snapshot.pilot().name());
        assertEquals("spark-v1", snapshot.pet().petId());
        assertEquals("Искра", snapshot.pet().name());
        assertEquals(0, snapshot.pet().evolutionStage());
        assertEquals(
                StarterExpeditionContent.ADULT_PET_FRONTIER_CONTENT_VERSION,
                snapshot.contentVersion()
        );
        assertEquals("starter-expedition-v1", snapshot.expedition().expeditionId());
        assertEquals(0, snapshot.inventory().size());
        assertEquals(2, snapshot.craftingRecipes().size());
        assertEquals("MISSING_MATERIALS",
                snapshot.craftingRecipes().getFirst().status());
        assertEquals(30, snapshot.expedition().progress());
        assertEquals("EVENT_READY", snapshot.expedition().status());
        assertNotNull(snapshot.expedition().unlockedEvent());
    }

    @Test
    void shouldNotDuplicateCompletedEventInsideExpeditionProjection() {
        StarterExpeditionContent content = new StarterExpeditionContent();
        var finalNode = content.requireNode(StarterExpeditionContent.FINAL_NODE_ID);
        HomeReadRepository repository = repository(
                new HomeRuntimeState(
                        12_000,
                        1,
                        "Europe/Berlin",
                        LAST_SYNC,
                        0,
                        1,
                        finalNode.requiredEnergy(),
                        finalNode.requiredEnergy(),
                        "COMPLETED",
                        36,
                        finalNode.currentNodeId(),
                        finalNode.event().eventId()
                )
        );
        DailyGoalPolicyProperties goalProperties = goalProperties();
        HomeService service = new HomeService(
                repository,
                new StarterHomeContent(),
                new DailyGoalService(
                        (userId, fromInclusive, toExclusive) -> List.of(),
                        new AdaptiveDailyGoalCalculator(goalProperties),
                        goalProperties
                ),
                content,
                Clock.fixed(NOW, ZoneOffset.UTC)
        );

        HomeSnapshotResponse snapshot = service.getSnapshot(
                new HomeQuery("user-1", LocalDate.of(2026, 7, 25))
        );

        assertEquals("COMPLETED", snapshot.expedition().status());
        assertNull(snapshot.expedition().unlockedEvent());
        assertEquals("MISSING_MATERIALS",
                snapshot.craftingRecipes().getFirst().status());
    }

    @Test
    void shouldRenderSelectedPetBeforeItsFirstReward() {
        HomeReadRepository repository = repository(
                new HomeRuntimeState(
                        0,
                        0,
                        "Europe/Berlin",
                        null,
                        0,
                        0,
                        0,
                        0,
                        null,
                        0,
                        null,
                        null,
                        false,
                        0,
                        0,
                        0,
                        "moss-v1",
                        false,
                        0,
                        0,
                        null,
                        null,
                        null,
                        null
                )
        );
        DailyGoalPolicyProperties goalProperties = goalProperties();
        HomeService service = new HomeService(
                repository,
                new StarterHomeContent(),
                new DailyGoalService(
                        (userId, fromInclusive, toExclusive) -> List.of(),
                        new AdaptiveDailyGoalCalculator(goalProperties),
                        goalProperties
                ),
                new StarterExpeditionContent(),
                Clock.fixed(NOW, ZoneOffset.UTC)
        );

        HomeSnapshotResponse snapshot = service.getSnapshot(
                new HomeQuery("user-1", LocalDate.of(2026, 7, 25))
        );

        assertEquals("Мох", snapshot.pet().name());
        assertEquals("moss-v1", snapshot.pet().petId());
        assertEquals("Терра", snapshot.pet().species());
        assertEquals(10, snapshot.pet().bond());
        assertEquals(0, snapshot.pet().evolutionStage());
    }

    @Test
    void shouldExposeAuthoritativeEvolutionStageForSelectedPet() {
        HomeReadRepository repository = repository(
                new HomeRuntimeState(
                        0,
                        0,
                        "Europe/Berlin",
                        null,
                        0,
                        0,
                        0,
                        0,
                        null,
                        0,
                        null,
                        null,
                        false,
                        0,
                        0,
                        0,
                        "moss-v1",
                        true,
                        2,
                        54,
                        1,
                        null,
                        null,
                        null,
                        null
                )
        );
        DailyGoalPolicyProperties goalProperties = goalProperties();
        HomeService service = new HomeService(
                repository,
                new StarterHomeContent(),
                new DailyGoalService(
                        (userId, fromInclusive, toExclusive) -> List.of(),
                        new AdaptiveDailyGoalCalculator(goalProperties),
                        goalProperties
                ),
                new StarterExpeditionContent(),
                Clock.fixed(NOW, ZoneOffset.UTC)
        );

        HomeSnapshotResponse snapshot = service.getSnapshot(
                new HomeQuery("user-1", LocalDate.of(2026, 7, 25))
        );

        assertEquals("moss-v1", snapshot.pet().petId());
        assertEquals(2, snapshot.pet().level());
        assertEquals(54, snapshot.pet().bond());
        assertEquals(1, snapshot.pet().evolutionStage());
    }

    private DailyGoalPolicyProperties goalProperties() {
        return new DailyGoalPolicyProperties(
                "adaptive-median-v1",
                7,
                3,
                6_000,
                2_000,
                12_000,
                5,
                250
        );
    }

    private HomeReadRepository repository(HomeRuntimeState state) {
        return new HomeReadRepository() {
            @Override
            public HomeRuntimeState findState(
                    String userId,
                    LocalDate localDate,
                    String expeditionId
            ) {
                return state;
            }

            @Override
            public Optional<ProcessedEventResolution> findPendingEventResult(
                    String userId,
                    String expeditionId
            ) {
                return Optional.empty();
            }
        };
    }
}
