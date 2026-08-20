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
import com.walkingrpg.backend.home.domain.ExpeditionJourneyChronicleTotals;
import com.walkingrpg.backend.home.domain.ExpeditionJourneyDecisionOutcomeSnapshot;
import com.walkingrpg.backend.home.domain.ExpeditionJourneyEvent;
import com.walkingrpg.backend.home.domain.ExpeditionJourneyFinaleOutcomeSnapshot;
import com.walkingrpg.backend.home.domain.ExpeditionJourneyHistory;
import com.walkingrpg.backend.home.domain.ExpeditionJourneyPilotExperienceRewardSnapshot;
import com.walkingrpg.backend.home.domain.HomeQuery;
import com.walkingrpg.backend.home.domain.HomeRuntimeState;
import com.walkingrpg.backend.home.domain.MaterialRewardPreviewSnapshot;
import com.walkingrpg.backend.home.domain.PetBondRewardSnapshot;
import com.walkingrpg.backend.home.infrastructure.HomeReadRepository;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class HomeServiceTest {

    private static final Instant NOW = Instant.parse("2026-07-25T12:00:00Z");
    private static final Instant LAST_SYNC = Instant.parse("2026-07-25T11:55:00Z");

    @Test
    void shouldRejectLongestJourneyDurationOutsideLifetimeTotal() {
        assertThrows(IllegalArgumentException.class, () ->
                new ExpeditionJourneyChronicleTotals(
                        1,
                        0,
                        60L,
                        61L,
                        0,
                        0,
                        List.of(),
                        List.of(),
                        List.of(),
                        List.of(),
                        List.of()
                ));
    }

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
        assertEquals("navigator-v1", snapshot.pilot().pilotId());
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
    void shouldOmitIncompletePilotExperienceBreakdown() {
        HomeReadRepository repository = repository(
                new HomeRuntimeState(
                        0,
                        0,
                        "Europe/Berlin",
                        null,
                        0,
                        0,
                        30,
                        30,
                        "EVENT_READY",
                        1,
                        "outer-beacon",
                        "signal-source-v1"
                ),
                List.of(),
                List.of(),
                new ExpeditionJourneyChronicleTotals(
                        1,
                        1,
                        40,
                        0,
                        List.of(
                                new ExpeditionJourneyPilotExperienceRewardSnapshot(
                                        "navigator-v1",
                                        "Навигатор из записи",
                                        39
                                )
                        ),
                        List.of(),
                        List.of(),
                        List.of(),
                        List.of()
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

        var chronicle = service.getSnapshot(
                new HomeQuery("user-1", LocalDate.of(2026, 7, 25))
        ).expedition().journeyChronicle();

        assertNotNull(chronicle);
        assertNull(chronicle.totalDurationSeconds());
        assertNull(chronicle.longestDurationSeconds());
        assertEquals(40, chronicle.pilotExperienceGained());
        assertTrue(chronicle.pilotExperienceRewards().isEmpty());
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
        assertNotNull(snapshot.expedition().completionRecap());
        assertNull(snapshot.expedition().completionRecap().finalDecision());
        assertNull(snapshot.expedition().completionRecap().durationSeconds());
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
                StarterExpeditionContent.MIRROR_DELTA_NODE_ID
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
                        journeyEventForPilot(
                                StarterExpeditionContent.SECOND_EVENT_ID,
                                "Сердце маяка из записи",
                                "stabilize-core",
                                "Стабилизировать ядро",
                                "Ровный импульс",
                                "Сохранён финальный маршрут.",
                                20,
                                "archivist-v1",
                                "Архивариус из записи",
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
                ),
                List.of(),
                new ExpeditionJourneyChronicleTotals(
                        7,
                        7,
                        12_600L,
                        3_600L,
                        28,
                        28,
                        List.of(
                                new ExpeditionJourneyPilotExperienceRewardSnapshot(
                                        "archivist-v1",
                                        "Архивариус из записи",
                                        8
                                ),
                                new ExpeditionJourneyPilotExperienceRewardSnapshot(
                                        "navigator-v1",
                                        "Навигатор из записи",
                                        20
                                )
                        ),
                        List.of(
                                new PetBondRewardSnapshot(
                                        "moss-v1",
                                        "Мох из записи",
                                        8
                                ),
                                new PetBondRewardSnapshot(
                                        "spark-v1",
                                        "Искра из записи",
                                        20
                                )
                        ),
                        List.of(
                                new MaterialRewardPreviewSnapshot(
                                        "ash-seed",
                                        "Пепельное семя из записи",
                                        4
                                ),
                                new MaterialRewardPreviewSnapshot(
                                        "echo-thread",
                                        "Эхо-нити из записи",
                                        7
                                )
                        ),
                        List.of(
                                new ExpeditionJourneyDecisionOutcomeSnapshot(
                                        StarterExpeditionContent.FIRST_EVENT_ID,
                                        "Первый сигнал из записи",
                                        "analyze-signal",
                                        "Разобрать сигнал",
                                        "Карта отклика",
                                        4
                                ),
                                new ExpeditionJourneyDecisionOutcomeSnapshot(
                                        StarterExpeditionContent.SECOND_EVENT_ID,
                                        "Сердце маяка из записи",
                                        "stabilize-core",
                                        "Стабилизировать ядро",
                                        "Ровный импульс",
                                        3
                                )
                        ),
                        List.of(
                                new ExpeditionJourneyFinaleOutcomeSnapshot(
                                        StarterExpeditionContent.SECOND_EVENT_ID,
                                        "Сердце маяка из записи",
                                        "stabilize-core",
                                        "Стабилизировать ядро",
                                        "Ровный импульс",
                                        4
                                ),
                                new ExpeditionJourneyFinaleOutcomeSnapshot(
                                        StarterExpeditionContent
                                                .MIRROR_DELTA_EVENT_ID,
                                        "Зеркальная дельта из записи",
                                        "follow-reflection",
                                        "Следовать за отражением",
                                        "Отражение принято",
                                        3
                                )
                        )
                ),
                NOW.minusSeconds(3_900)
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
        var recap = expedition.completionRecap();

        assertNotNull(recap);
        assertEquals(1, recap.journeyNumber());
        assertEquals(3, recap.decisionCount());
        assertEquals(3, recap.decisions().size());
        assertEquals("Первый сигнал из записи",
                recap.decisions().getFirst().eventTitle());
        assertEquals("Разобрать сигнал",
                recap.decisions().getFirst().choiceTitle());
        assertEquals("Зеркальная дельта из записи",
                recap.decisions().getLast().eventTitle());
        assertEquals("Искра из записи",
                recap.decisions().getLast().petName());
        assertEquals(1,
                recap.decisions().getLast().materialReward().quantity());
        assertNotNull(recap.finalDecision());
        assertEquals(StarterExpeditionContent.MIRROR_DELTA_EVENT_ID,
                recap.finalDecision().eventId());
        assertEquals("Зеркальная дельта из записи",
                recap.finalDecision().eventTitle());
        assertEquals("Следовать за отражением",
                recap.finalDecision().choiceTitle());
        assertEquals("Отражение принято",
                recap.finalDecision().outcomeTitle());
        assertEquals("Искра сохранила отклик дельты.",
                recap.finalDecision().outcomeSummary());
        assertEquals(NOW, recap.finalDecision().resolvedAt());
        assertEquals(3_900, recap.durationSeconds());
        assertEquals(70, recap.pilotExperienceGained());
        assertEquals(2, recap.pilotExperienceRewards().size());
        assertEquals("navigator-v1",
                recap.pilotExperienceRewards().getFirst().pilotId());
        assertEquals("Навигатор из записи",
                recap.pilotExperienceRewards().getFirst().pilotName());
        assertEquals(50,
                recap.pilotExperienceRewards().getFirst().experienceGained());
        assertEquals("archivist-v1",
                recap.pilotExperienceRewards().getLast().pilotId());
        assertEquals("Архивариус из записи",
                recap.pilotExperienceRewards().getLast().pilotName());
        assertEquals(20,
                recap.pilotExperienceRewards().getLast().experienceGained());
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
        assertNotNull(expedition.journeyChronicle());
        assertEquals(8,
                expedition.journeyChronicle().completedJourneyCount());
        assertEquals(10, expedition.journeyChronicle().decisionCount());
        assertEquals(16_500,
                expedition.journeyChronicle().totalDurationSeconds());
        assertEquals(3_900,
                expedition.journeyChronicle().longestDurationSeconds());
        assertEquals(98,
                expedition.journeyChronicle().pilotExperienceGained());
        assertEquals(2,
                expedition.journeyChronicle()
                        .pilotExperienceRewards().size());
        assertEquals("archivist-v1",
                expedition.journeyChronicle().pilotExperienceRewards()
                        .getFirst().pilotId());
        assertEquals(28,
                expedition.journeyChronicle().pilotExperienceRewards()
                        .getFirst().experienceGained());
        assertEquals("navigator-v1",
                expedition.journeyChronicle().pilotExperienceRewards()
                        .getLast().pilotId());
        assertEquals("Навигатор из записи",
                expedition.journeyChronicle().pilotExperienceRewards()
                        .getLast().pilotName());
        assertEquals(70,
                expedition.journeyChronicle().pilotExperienceRewards()
                        .getLast().experienceGained());
        assertEquals(51,
                expedition.journeyChronicle().petBondGained());
        assertEquals(2,
                expedition.journeyChronicle().petBondRewards().size());
        assertEquals("moss-v1",
                expedition.journeyChronicle().petBondRewards()
                        .getFirst().petId());
        assertEquals(23,
                expedition.journeyChronicle().petBondRewards()
                        .getFirst().bondGained());
        assertEquals("spark-v1",
                expedition.journeyChronicle().petBondRewards()
                        .getLast().petId());
        assertEquals(28,
                expedition.journeyChronicle().petBondRewards()
                        .getLast().bondGained());
        assertEquals(2,
                expedition.journeyChronicle().materials().size());
        assertEquals("ash-seed",
                expedition.journeyChronicle().materials()
                        .getFirst().itemId());
        assertEquals(4,
                expedition.journeyChronicle().materials()
                        .getFirst().quantity());
        assertEquals("echo-thread",
                expedition.journeyChronicle().materials()
                        .getLast().itemId());
        assertEquals(13,
                expedition.journeyChronicle().materials()
                        .getLast().quantity());
        assertEquals(3,
                expedition.journeyChronicle().decisionOutcomes().size());
        assertEquals(StarterExpeditionContent.FIRST_EVENT_ID,
                expedition.journeyChronicle().decisionOutcomes()
                        .getFirst().eventId());
        assertEquals("Разобрать сигнал",
                expedition.journeyChronicle().decisionOutcomes()
                        .getFirst().choiceTitle());
        assertEquals(5,
                expedition.journeyChronicle().decisionOutcomes()
                        .getFirst().decisionCount());
        assertEquals(StarterExpeditionContent.SECOND_EVENT_ID,
                expedition.journeyChronicle().decisionOutcomes()
                        .get(1).eventId());
        assertEquals(4,
                expedition.journeyChronicle().decisionOutcomes()
                        .get(1).decisionCount());
        assertEquals(StarterExpeditionContent.MIRROR_DELTA_EVENT_ID,
                expedition.journeyChronicle().decisionOutcomes()
                        .getLast().eventId());
        assertEquals("Отражение принято",
                expedition.journeyChronicle().decisionOutcomes()
                        .getLast().outcomeTitle());
        assertEquals(1,
                expedition.journeyChronicle().decisionOutcomes()
                        .getLast().decisionCount());
        assertEquals(2,
                expedition.journeyChronicle().finaleOutcomes().size());
        assertEquals(StarterExpeditionContent.SECOND_EVENT_ID,
                expedition.journeyChronicle().finaleOutcomes()
                        .getFirst().eventId());
        assertEquals("Стабилизировать ядро",
                expedition.journeyChronicle().finaleOutcomes()
                        .getFirst().choiceTitle());
        assertEquals(4,
                expedition.journeyChronicle().finaleOutcomes()
                        .getFirst().journeyCount());
        assertEquals(StarterExpeditionContent.MIRROR_DELTA_EVENT_ID,
                expedition.journeyChronicle().finaleOutcomes()
                        .getLast().eventId());
        assertEquals("Зеркальная дельта из записи",
                expedition.journeyChronicle().finaleOutcomes()
                        .getLast().eventTitle());
        assertEquals("Отражение принято",
                expedition.journeyChronicle().finaleOutcomes()
                        .getLast().outcomeTitle());
        assertEquals(4,
                expedition.journeyChronicle().finaleOutcomes()
                        .getLast().journeyCount());
        assertEquals("COMPLETED", expedition.routeTrail().getLast().state());
        assertNotNull(expedition.routeTrail().getLast().decision());
        assertEquals("Следовать за отражением",
                expedition.routeTrail().getLast().decision().choiceTitle());
        assertEquals("Отражение принято",
                expedition.routeTrail().getLast().decision().outcomeTitle());
    }

    @Test
    void shouldOmitJourneyPilotBreakdownWhenPersistedIdentityIsIncomplete() {
        StarterExpeditionContent content = new StarterExpeditionContent();
        var finalNode = content.requireNode(
                StarterExpeditionContent.FINAL_NODE_ID
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
                        1,
                        finalNode.currentNodeId(),
                        finalNode.event().eventId()
                ),
                List.of(new ExpeditionJourneyEvent(
                        StarterExpeditionContent.FIRST_EVENT_ID,
                        "Сигнал из старой записи",
                        "analyze-signal",
                        "Разобрать сигнал",
                        "Карта отклика",
                        "Старый маршрут сохранён.",
                        40,
                        null,
                        null,
                        "spark-v1",
                        "Искра",
                        5,
                        null,
                        NOW
                ))
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

        assertEquals(40,
                expedition.completionRecap().pilotExperienceGained());
        assertTrue(expedition.completionRecap()
                .pilotExperienceRewards().isEmpty());
        assertEquals(40,
                expedition.journeyChronicle().pilotExperienceGained());
        assertTrue(expedition.journeyChronicle()
                .pilotExperienceRewards().isEmpty());
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
                                NOW.minusSeconds(1_800),
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
                                NOW,
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
        assertEquals(1_800,
                expedition.recentJourneyRecaps().getFirst()
                        .durationSeconds());
        assertEquals(20,
                expedition.recentJourneyRecaps().getFirst()
                        .pilotExperienceGained());
        assertEquals(1,
                expedition.recentJourneyRecaps().getFirst()
                        .pilotExperienceRewards().size());
        assertEquals("navigator-v1",
                expedition.recentJourneyRecaps().getFirst()
                        .pilotExperienceRewards().getFirst().pilotId());
        assertEquals("Навигатор из записи",
                expedition.recentJourneyRecaps().getFirst()
                        .pilotExperienceRewards().getFirst().pilotName());
        assertEquals(20,
                expedition.recentJourneyRecaps().getFirst()
                        .pilotExperienceRewards().getFirst()
                        .experienceGained());
        assertEquals(1,
                expedition.recentJourneyRecaps().getFirst()
                        .decisions().size());
        assertEquals("Сердце второго похода",
                expedition.recentJourneyRecaps().getFirst()
                        .decisions().getFirst().eventTitle());
        assertEquals("Второй маршрут сохранён.",
                expedition.recentJourneyRecaps().getFirst()
                        .decisions().getFirst().outcomeSummary());
        assertEquals(3,
                expedition.recentJourneyRecaps().getFirst()
                        .decisions().getFirst().materialReward().quantity());
        assertEquals("Сердце второго похода",
                expedition.recentJourneyRecaps().getFirst()
                        .finalDecision().eventTitle());
        assertEquals("Ровный импульс",
                expedition.recentJourneyRecaps().getFirst()
                        .finalDecision().outcomeTitle());
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
        assertNull(expedition.recentJourneyRecaps().getLast()
                .durationSeconds());
        assertEquals(40,
                expedition.recentJourneyRecaps().getLast()
                        .pilotExperienceRewards().getFirst()
                        .experienceGained());
        assertEquals(5,
                expedition.recentJourneyRecaps().getLast().petBondGained());
        assertEquals("Мох",
                expedition.recentJourneyRecaps().getLast()
                        .petBondRewards().getFirst().petName());
        assertEquals("Карта отклика",
                expedition.recentJourneyRecaps().getLast()
                        .finalDecision().outcomeTitle());
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
        assertNotNull(trail.get(0).decision());
        assertEquals("analyze-signal",
                trail.get(0).decision().choiceId());
        assertEquals("Разобрать сигнал",
                trail.get(0).decision().choiceTitle());
        assertEquals("Карта отклика",
                trail.get(0).decision().outcomeTitle());
        assertEquals(StarterExpeditionContent.SECOND_NODE_ID,
                trail.get(1).nodeId());
        assertEquals("VISITED", trail.get(1).state());
        assertNotNull(trail.get(1).decision());
        assertEquals("Стабилизировать ядро",
                trail.get(1).decision().choiceTitle());
        assertEquals("Ровный импульс",
                trail.get(1).decision().outcomeTitle());
        assertEquals(StarterExpeditionContent.THIRD_NODE_ID,
                trail.get(2).nodeId());
        assertEquals("CURRENT", trail.get(2).state());
        assertNull(trail.get(2).decision());
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
                "navigator-v1",
                "Навигатор из записи",
                petId,
                petName,
                petBondGained,
                materialReward,
                resolvedAt
        );
    }

    private ExpeditionJourneyEvent journeyEventForPilot(
            String eventId,
            String eventTitle,
            String choiceId,
            String choiceTitle,
            String outcomeTitle,
            String outcomeSummary,
            int pilotExperienceGained,
            String pilotId,
            String pilotName,
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
                pilotId,
                pilotName,
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
        return repository(
                state,
                journeyEvents,
                recentJourneyHistory,
                ExpeditionJourneyChronicleTotals.empty()
        );
    }

    private HomeReadRepository repository(
            HomeRuntimeState state,
            List<ExpeditionJourneyEvent> journeyEvents,
            List<ExpeditionJourneyHistory> recentJourneyHistory,
            ExpeditionJourneyChronicleTotals journeyChronicle
    ) {
        return repository(
                state,
                journeyEvents,
                recentJourneyHistory,
                journeyChronicle,
                null
        );
    }

    private HomeReadRepository repository(
            HomeRuntimeState state,
            List<ExpeditionJourneyEvent> journeyEvents,
            List<ExpeditionJourneyHistory> recentJourneyHistory,
            ExpeditionJourneyChronicleTotals journeyChronicle,
            Instant journeyStartedAt
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
            public Optional<Instant> findJourneyStartedAt(
                    String userId,
                    String expeditionId,
                    long journeyNumber
            ) {
                return Optional.ofNullable(journeyStartedAt);
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

            @Override
            public ExpeditionJourneyChronicleTotals findCompletedJourneyChronicle(
                    String userId,
                    String expeditionId,
                    long currentJourneyNumber
            ) {
                return journeyChronicle;
            }
        };
    }
}
