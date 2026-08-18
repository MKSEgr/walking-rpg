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
import com.walkingrpg.backend.home.domain.ExpeditionJourneyEvent;
import com.walkingrpg.backend.home.domain.ExpeditionJourneyHistory;
import com.walkingrpg.backend.home.domain.HomeQuery;
import com.walkingrpg.backend.home.domain.HomeRuntimeState;
import com.walkingrpg.backend.home.domain.MaterialRewardPreviewSnapshot;
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
                StarterExpeditionContent
                        .STEADY_STEP_ROUTE_CONTENT_VERSION,
                snapshot.contentVersion()
        );
        assertEquals("starter-expedition-v1", snapshot.expedition().expeditionId());
        assertEquals(0, snapshot.inventory().size());
        assertEquals(2, snapshot.craftingRecipes().size());
        assertEquals("MISSING_MATERIALS",
                snapshot.craftingRecipes().getFirst().status());
        assertEquals(30, snapshot.expedition().progress());
        assertEquals(1, snapshot.expedition().journeyNumber());
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
        assertEquals(1, snapshot.expedition().routeTrail().size());
        assertEquals("COMPLETED",
                snapshot.expedition().routeTrail().getFirst().state());
        assertEquals("MISSING_MATERIALS",
                snapshot.craftingRecipes().getFirst().status());
    }

    @Test
    void shouldSummarizePersistedRewardsOnlyAfterJourneyCompletion() {
        StarterExpeditionContent content = new StarterExpeditionContent();
        var finalNode = content.requireNode(
                StarterExpeditionContent.THIRD_NODE_ID
        );
        HomeReadRepository repository = repository(
                new HomeRuntimeState(
                        0,
                        0,
                        "Europe/Berlin",
                        null,
                        0,
                        0,
                        finalNode.requiredEnergy(),
                        finalNode.requiredEnergy(),
                        "COMPLETED",
                        8,
                        finalNode.currentNodeId(),
                        finalNode.event().eventId()
                ),
                List.of(
                        journeyEvent(
                                StarterExpeditionContent.FIRST_EVENT_ID,
                                "Первый сигнал из записи",
                                "analyze-signal",
                                "Разобрать сигнал",
                                "Карта отклика",
                                "Сохранён первый маршрут.",
                                40,
                                "spark-v1",
                                "Искра из записи",
                                5,
                                new MaterialRewardPreviewSnapshot(
                                        "echo-thread",
                                        "Эхо-нити из записи",
                                        2
                                ),
                                NOW.minusSeconds(120)
                        ),
                        journeyEvent(
                                StarterExpeditionContent.SECOND_EVENT_ID,
                                "Сердце маяка из записи",
                                "stabilize-core",
                                "Стабилизировать ядро",
                                "Ровный импульс",
                                "Сохранён финальный маршрут.",
                                20,
                                "moss-v1",
                                "Мох из записи",
                                15,
                                new MaterialRewardPreviewSnapshot(
                                        "echo-thread",
                                        "Эхо-нити из записи",
                                        3
                                ),
                                NOW.minusSeconds(60)
                        ),
                        journeyEvent(
                                StarterExpeditionContent.MIRROR_DELTA_EVENT_ID,
                                "Зеркальная дельта из записи",
                                "follow-reflection",
                                "Следовать за отражением",
                                "Отражение принято",
                                "Искра сохранила отклик дельты.",
                                10,
                                "spark-v1",
                                "Искра из записи",
                                3,
                                new MaterialRewardPreviewSnapshot(
                                        "echo-thread",
                                        "Эхо-нити из записи",
                                        1
                                ),
                                NOW
                        )
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

        var recap = service.getSnapshot(
                new HomeQuery("user-1", LocalDate.of(2026, 7, 25))
        ).expedition().completionRecap();

        assertNotNull(recap);
        assertEquals(1, recap.journeyNumber());
        assertEquals(3, recap.decisionCount());
        assertEquals(70, recap.pilotExperienceGained());
        assertEquals(23, recap.petBondGained());
        assertEquals(2, recap.petBondRewards().size());
        assertEquals("spark-v1",
                recap.petBondRewards().getFirst().petId());
        assertEquals("Искра из записи",
                recap.petBondRewards().getFirst().petName());
        assertEquals(8,
                recap.petBondRewards().getFirst().bondGained());
        assertEquals("moss-v1",
                recap.petBondRewards().getLast().petId());
        assertEquals(15,
                recap.petBondRewards().getLast().bondGained());
        assertEquals(1, recap.materials().size());
        assertEquals("echo-thread", recap.materials().getFirst().itemId());
        assertEquals("Эхо-нити из записи",
                recap.materials().getFirst().itemName());
        assertEquals(6, recap.materials().getFirst().quantity());
    }

    @Test
    void shouldProjectRecentCompletedJourneyRecapsInRepositoryOrder() {
        StarterExpeditionContent content = new StarterExpeditionContent();
        HomeRuntimeState state = new HomeRuntimeState(
                0,
                0,
                "Europe/Berlin",
                null,
                0,
                0,
                0,
                30,
                "IN_PROGRESS",
                9,
                3,
                StarterExpeditionContent.FIRST_NODE_ID,
                null,
                false,
                0,
                0,
                0,
                "spark-v1",
                false,
                0,
                0,
                0,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                null,
                List.of()
        );
        HomeReadRepository repository = repository(
                state,
                List.of(),
                List.of(
                        new ExpeditionJourneyHistory(
                                2,
                                List.of(journeyEvent(
                                        StarterExpeditionContent.SECOND_EVENT_ID,
                                        "Сердце второго похода",
                                        "stabilize-core",
                                        "Стабилизировать ядро",
                                        "Ровный импульс",
                                        "Второй маршрут сохранён.",
                                        20,
                                        "spark-v1",
                                        "Искра",
                                        7,
                                        new MaterialRewardPreviewSnapshot(
                                                "echo-thread",
                                                "Эхо-нити",
                                                3
                                        ),
                                        NOW
                                ))
                        ),
                        new ExpeditionJourneyHistory(
                                1,
                                List.of(journeyEvent(
                                        StarterExpeditionContent.FIRST_EVENT_ID,
                                        "Сигнал первого похода",
                                        "analyze-signal",
                                        "Разобрать сигнал",
                                        "Карта отклика",
                                        "Первый маршрут сохранён.",
                                        40,
                                        "moss-v1",
                                        "Мох",
                                        5,
                                        null,
                                        NOW.minusSeconds(60)
                                ))
                        )
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

        var expedition = service.getSnapshot(
                new HomeQuery("user-1", LocalDate.of(2026, 7, 25))
        ).expedition();

        assertNull(expedition.completionRecap());
        assertEquals(2, expedition.recentJourneyRecaps().size());
        assertEquals(2,
                expedition.recentJourneyRecaps().getFirst().journeyNumber());
        assertEquals(20,
                expedition.recentJourneyRecaps().getFirst()
                        .pilotExperienceGained());
        assertEquals(3,
                expedition.recentJourneyRecaps().getFirst()
                        .materials().getFirst().quantity());
        assertEquals("spark-v1",
                expedition.recentJourneyRecaps().getFirst()
                        .petBondRewards().getFirst().petId());
        assertEquals(7,
                expedition.recentJourneyRecaps().getFirst()
                        .petBondRewards().getFirst().bondGained());
        assertEquals(1,
                expedition.recentJourneyRecaps().getLast().journeyNumber());
        assertEquals(5,
                expedition.recentJourneyRecaps().getLast().petBondGained());
        assertEquals("Мох",
                expedition.recentJourneyRecaps().getLast()
                        .petBondRewards().getFirst().petName());
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

    @Test
    void shouldProjectOnlyPersistedJourneyEventsBeforeCurrentNode() {
        StarterExpeditionContent content = new StarterExpeditionContent();
        HomeReadRepository repository = repository(
                new HomeRuntimeState(
                        0,
                        0,
                        "Europe/Berlin",
                        null,
                        0,
                        0,
                        0,
                        content.requireNode(
                                StarterExpeditionContent.THIRD_NODE_ID
                        ).requiredEnergy(),
                        "IN_PROGRESS",
                        4,
                        StarterExpeditionContent.THIRD_NODE_ID,
                        null
                ),
                List.of(
                        journeyEvent(
                                StarterExpeditionContent.FIRST_EVENT_ID,
                                "Первый сигнал",
                                "analyze-signal",
                                "Разобрать сигнал",
                                "Карта отклика",
                                "Навигатор сохранил первый маршрут.",
                                40,
                                "spark-v1",
                                "Искра из записи",
                                5,
                                null,
                                NOW.minusSeconds(60)
                        ),
                        journeyEvent(
                                StarterExpeditionContent.SECOND_EVENT_ID,
                                "Сердце маяка",
                                "stabilize-core",
                                "Стабилизировать ядро",
                                "Ровный импульс",
                                "Маяк удержал безопасный курс.",
                                20,
                                "moss-v1",
                                "Мох из записи",
                                15,
                                new MaterialRewardPreviewSnapshot(
                                        "echo-thread",
                                        "Эхо-нити из записи",
                                        3
                                ),
                                NOW
                        )
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

        var expedition = service.getSnapshot(
                new HomeQuery("user-1", LocalDate.of(2026, 7, 25))
        ).expedition();
        var trail = expedition.routeTrail();

        assertEquals(3, trail.size());
        assertEquals(StarterExpeditionContent.FIRST_NODE_ID,
                trail.get(0).nodeId());
        assertEquals("VISITED", trail.get(0).state());
        assertEquals(StarterExpeditionContent.SECOND_NODE_ID,
                trail.get(1).nodeId());
        assertEquals("VISITED", trail.get(1).state());
        assertEquals(StarterExpeditionContent.THIRD_NODE_ID,
                trail.get(2).nodeId());
        assertEquals("CURRENT", trail.get(2).state());
        assertEquals(2, expedition.decisionLog().size());
        assertNull(expedition.completionRecap());
        assertEquals("Первый сигнал",
                expedition.decisionLog().getFirst().eventTitle());
        assertEquals("Разобрать сигнал",
                expedition.decisionLog().getFirst().choiceTitle());
        assertEquals("Ровный импульс",
                expedition.decisionLog().getLast().outcomeTitle());
        assertEquals(40,
                expedition.decisionLog().getFirst().pilotExperienceGained());
        assertEquals("Мох из записи",
                expedition.decisionLog().getLast().petName());
        assertEquals(15,
                expedition.decisionLog().getLast().petBondGained());
        assertEquals("Эхо-нити из записи",
                expedition.decisionLog().getLast().materialReward().itemName());
        assertEquals(3,
                expedition.decisionLog().getLast().materialReward().quantity());
        assertEquals(NOW, expedition.decisionLog().getLast().resolvedAt());
    }

    private ExpeditionJourneyEvent journeyEvent(
            String eventId,
            String eventTitle,
            String choiceId,
            String choiceTitle,
            String outcomeTitle,
            String outcomeSummary,
            int pilotExperienceGained,
            String petId,
            String petName,
            int petBondGained,
            MaterialRewardPreviewSnapshot materialReward,
            Instant resolvedAt
    ) {
        return new ExpeditionJourneyEvent(
                eventId,
                eventTitle,
                choiceId,
                choiceTitle,
                outcomeTitle,
                outcomeSummary,
                pilotExperienceGained,
                petId,
                petName,
                petBondGained,
                materialReward,
                resolvedAt
        );
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
        return repository(state, List.of());
    }

    private HomeReadRepository repository(
            HomeRuntimeState state,
            List<ExpeditionJourneyEvent> journeyEvents
    ) {
        return repository(state, journeyEvents, List.of());
    }

    private HomeReadRepository repository(
            HomeRuntimeState state,
            List<ExpeditionJourneyEvent> journeyEvents,
            List<ExpeditionJourneyHistory> recentJourneyHistory
    ) {
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

            @Override
            public List<ExpeditionJourneyEvent> findJourneyEvents(
                    String userId,
                    String expeditionId,
                    long journeyNumber
            ) {
                return journeyEvents;
            }

            @Override
            public List<ExpeditionJourneyHistory> findRecentCompletedJourneys(
                    String userId,
                    String expeditionId,
                    long currentJourneyNumber,
                    int limit
            ) {
                return recentJourneyHistory;
            }
        };
    }
}
