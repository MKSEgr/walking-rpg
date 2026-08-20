package com.walkingrpg.backend.home.api;

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
import com.walkingrpg.backend.home.application.HomeQueryFactory;
import com.walkingrpg.backend.home.application.HomeService;
import com.walkingrpg.backend.home.application.StarterHomeContent;
import com.walkingrpg.backend.home.domain.ExpeditionJourneyChronicleTotals;
import com.walkingrpg.backend.home.domain.ExpeditionJourneyEvent;
import com.walkingrpg.backend.home.domain.ExpeditionJourneyHistory;
import com.walkingrpg.backend.home.domain.HomeRuntimeState;
import com.walkingrpg.backend.home.domain.MaterialRewardPreviewSnapshot;
import com.walkingrpg.backend.home.infrastructure.HomeReadRepository;
import com.walkingrpg.backend.security.FixedRequestIdentityProvider;
import com.walkingrpg.backend.shared.api.ApiExceptionHandler;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class HomeControllerTest {

    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        HomeReadRepository repository = repository(
                new HomeRuntimeState(
                        6_842,
                        1,
                        "Europe/Berlin",
                        Instant.parse("2026-07-25T11:55:00Z"),
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
        DailyGoalPolicyProperties goalProperties = new DailyGoalPolicyProperties(
                "adaptive-median-v1",
                7,
                3,
                6_000,
                2_000,
                12_000,
                5,
                250
        );
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
                Clock.fixed(Instant.parse("2026-07-25T12:00:00Z"), ZoneOffset.UTC)
        );
        HomeController controller = new HomeController(
                new HomeQueryFactory(),
                service,
                FixedRequestIdentityProvider.user("user-1")
        );
        mockMvc = MockMvcBuilders.standaloneSetup(controller)
                .setControllerAdvice(new ApiExceptionHandler())
                .build();
    }

    @Test
    void shouldReturnProductionHomeSnapshot() throws Exception {
        mockMvc.perform(get("/api/v1/home")
                        .queryParam("localDate", "2026-07-25"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.localDate").value("2026-07-25"))
                .andExpect(jsonPath("$.timeZone").value("Europe/Berlin"))
                .andExpect(jsonPath("$.dailySteps").value(6842))
                .andExpect(jsonPath("$.dailyGoal").value(3250))
                .andExpect(jsonPath("$.dailyGoalPolicy.policyVersion")
                        .value("adaptive-median-v1"))
                .andExpect(jsonPath("$.dailyGoalPolicy.source").value("ADAPTIVE"))
                .andExpect(jsonPath("$.dailyGoalPolicy.baselineSteps").value(3000))
                .andExpect(jsonPath("$.dailyGoalPolicy.sampleDays").value(3))
                .andExpect(jsonPath("$.dailyGoalPolicy.defaultGoal").value(6000))
                .andExpect(jsonPath("$.availableEnergy").value(38))
                .andExpect(jsonPath("$.activityStateVersion").value(1))
                .andExpect(jsonPath("$.economyVersion").value(2))
                .andExpect(jsonPath("$.contentVersion")
                        .value(
                                StarterExpeditionContent
                                        .STEADY_STEP_ROUTE_CONTENT_VERSION
                        ))
                .andExpect(jsonPath("$.pilot.pilotId").value("navigator-v1"))
                .andExpect(jsonPath("$.pilot.name").value("Навигатор"))
                .andExpect(jsonPath("$.pet.petId").value("spark-v1"))
                .andExpect(jsonPath("$.pet.name").value("Искра"))
                .andExpect(jsonPath("$.pet.evolutionStage").value(0))
                .andExpect(jsonPath("$.inventory").isArray())
                .andExpect(jsonPath("$.inventory").isEmpty())
                .andExpect(jsonPath("$.craftingRecipes.length()").value(2))
                .andExpect(jsonPath("$.craftingRecipes[0].status")
                        .value("MISSING_MATERIALS"))
                .andExpect(jsonPath("$.expedition.expeditionId")
                        .value("starter-expedition-v1"))
                .andExpect(jsonPath("$.expedition.progress").value(30))
                .andExpect(jsonPath("$.expedition.journeyNumber").value(1))
                .andExpect(jsonPath("$.expedition.routeTrail.length()").value(1))
                .andExpect(jsonPath("$.expedition.routeTrail[0].nodeId")
                        .value("outer-beacon"))
                .andExpect(jsonPath("$.expedition.routeTrail[0].state")
                        .value("CURRENT"))
                .andExpect(jsonPath("$.expedition.decisionLog").isArray())
                .andExpect(jsonPath("$.expedition.decisionLog").isEmpty())
                .andExpect(jsonPath("$.expedition.status").value("EVENT_READY"))
                .andExpect(jsonPath("$.expedition.unlockedEvent.eventId")
                        .value("signal-source-v1"));
    }

    @Test
    void shouldReturnPersistedJourneyDecisionLog() throws Exception {
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
                                StarterExpeditionContent.SECOND_NODE_ID
                        ).requiredEnergy(),
                        "IN_PROGRESS",
                        2,
                        StarterExpeditionContent.SECOND_NODE_ID,
                        null
                ),
                List.of(new ExpeditionJourneyEvent(
                        StarterExpeditionContent.FIRST_EVENT_ID,
                        "Сигнал у границы",
                        "analyze-signal",
                        "Разобрать сигнал",
                        "Карта отклика",
                        "Сохранён безопасный путь к маяку.",
                        48,
                        "navigator-v1",
                        "Навигатор из записи",
                        "spark-v1",
                        "Искра из записи",
                        11,
                        new MaterialRewardPreviewSnapshot(
                                "echo-thread",
                                "Эхо-нити из записи",
                                2
                        ),
                        Instant.parse("2026-07-25T11:58:00Z")
                ))
        );
        DailyGoalPolicyProperties goalProperties =
                new DailyGoalPolicyProperties(
                        "adaptive-median-v1",
                        7,
                        3,
                        6_000,
                        2_000,
                        12_000,
                        5,
                        250
                );
        HomeService service = new HomeService(
                repository,
                new StarterHomeContent(),
                new DailyGoalService(
                        (userId, fromInclusive, toExclusive) -> List.of(),
                        new AdaptiveDailyGoalCalculator(goalProperties),
                        goalProperties
                ),
                content,
                Clock.fixed(
                        Instant.parse("2026-07-25T12:00:00Z"),
                        ZoneOffset.UTC
                )
        );
        MockMvc decisionLogMockMvc = MockMvcBuilders.standaloneSetup(
                        new HomeController(
                                new HomeQueryFactory(),
                                service,
                                FixedRequestIdentityProvider.user("user-1")
                        )
                )
                .setControllerAdvice(new ApiExceptionHandler())
                .build();

        decisionLogMockMvc.perform(get("/api/v1/home")
                        .queryParam("localDate", "2026-07-25"))
                .andExpect(status().isOk())
                .andExpect(jsonPath(
                        "$.expedition.routeTrail[0].decision.choiceId"
                ).value("analyze-signal"))
                .andExpect(jsonPath(
                        "$.expedition.routeTrail[0].decision.choiceTitle"
                ).value("Разобрать сигнал"))
                .andExpect(jsonPath(
                        "$.expedition.routeTrail[0].decision.outcomeTitle"
                ).value("Карта отклика"))
                .andExpect(jsonPath("$.expedition.routeTrail[1].decision")
                        .doesNotExist())
                .andExpect(jsonPath("$.expedition.decisionLog.length()")
                        .value(1))
                .andExpect(jsonPath("$.expedition.decisionLog[0].eventId")
                        .value(StarterExpeditionContent.FIRST_EVENT_ID))
                .andExpect(jsonPath("$.expedition.decisionLog[0].eventTitle")
                        .value("Сигнал у границы"))
                .andExpect(jsonPath("$.expedition.decisionLog[0].choiceId")
                        .value("analyze-signal"))
                .andExpect(jsonPath("$.expedition.decisionLog[0].choiceTitle")
                        .value("Разобрать сигнал"))
                .andExpect(jsonPath("$.expedition.decisionLog[0].outcomeTitle")
                        .value("Карта отклика"))
                .andExpect(jsonPath("$.expedition.decisionLog[0].outcomeSummary")
                        .value("Сохранён безопасный путь к маяку."))
                .andExpect(jsonPath(
                        "$.expedition.decisionLog[0].pilotExperienceGained"
                ).value(48))
                .andExpect(jsonPath("$.expedition.decisionLog[0].petId")
                        .value("spark-v1"))
                .andExpect(jsonPath("$.expedition.decisionLog[0].petName")
                        .value("Искра из записи"))
                .andExpect(jsonPath("$.expedition.decisionLog[0].petBondGained")
                        .value(11))
                .andExpect(jsonPath(
                        "$.expedition.decisionLog[0].materialReward.itemId"
                ).value("echo-thread"))
                .andExpect(jsonPath(
                        "$.expedition.decisionLog[0].materialReward.itemName"
                ).value("Эхо-нити из записи"))
                .andExpect(jsonPath(
                        "$.expedition.decisionLog[0].materialReward.quantity"
                ).value(2))
                .andExpect(jsonPath("$.expedition.decisionLog[0].resolvedAt")
                        .value("2026-07-25T11:58:00Z"))
                .andExpect(jsonPath("$.expedition.completionRecap")
                        .doesNotExist())
                .andExpect(jsonPath("$.expedition.journeyChronicle")
                        .doesNotExist());
    }

    @Test
    void shouldReturnCompletionRecapFromPersistedJourneyRewards()
            throws Exception {
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
                        3,
                        finalNode.currentNodeId(),
                        null
                ),
                List.of(new ExpeditionJourneyEvent(
                        StarterExpeditionContent.SECOND_EVENT_ID,
                        "Сердце маяка из записи",
                        "stabilize-core",
                        "Стабилизировать ядро",
                        "Ровный импульс",
                        "Сохранён финальный маршрут.",
                        48,
                        "navigator-v1",
                        "Навигатор из записи",
                        "spark-v1",
                        "Искра из записи",
                        11,
                        new MaterialRewardPreviewSnapshot(
                                "echo-thread",
                                "Эхо-нити из записи",
                                2
                        ),
                        Instant.parse("2026-07-25T11:58:00Z")
                ))
        );
        DailyGoalPolicyProperties goalProperties =
                new DailyGoalPolicyProperties(
                        "adaptive-median-v1",
                        7,
                        3,
                        6_000,
                        2_000,
                        12_000,
                        5,
                        250
                );
        HomeService service = new HomeService(
                repository,
                new StarterHomeContent(),
                new DailyGoalService(
                        (userId, fromInclusive, toExclusive) -> List.of(),
                        new AdaptiveDailyGoalCalculator(goalProperties),
                        goalProperties
                ),
                content,
                Clock.fixed(
                        Instant.parse("2026-07-25T12:00:00Z"),
                        ZoneOffset.UTC
                )
        );
        MockMvc completedMockMvc = MockMvcBuilders.standaloneSetup(
                        new HomeController(
                                new HomeQueryFactory(),
                                service,
                                FixedRequestIdentityProvider.user("user-1")
                        )
                )
                .setControllerAdvice(new ApiExceptionHandler())
                .build();

        completedMockMvc.perform(get("/api/v1/home")
                        .queryParam("localDate", "2026-07-25"))
                .andExpect(status().isOk())
                .andExpect(jsonPath(
                        "$.expedition.completionRecap.journeyNumber"
                ).value(1))
                .andExpect(jsonPath(
                        "$.expedition.completionRecap.decisionCount"
                ).value(1))
                .andExpect(jsonPath(
                        "$.expedition.completionRecap.decisions.length()"
                ).value(1))
                .andExpect(jsonPath(
                        "$.expedition.completionRecap.decisions[0].eventTitle"
                ).value("Сердце маяка из записи"))
                .andExpect(jsonPath(
                        "$.expedition.completionRecap.decisions[0].choiceTitle"
                ).value("Стабилизировать ядро"))
                .andExpect(jsonPath(
                        "$.expedition.completionRecap.decisions[0].outcomeTitle"
                ).value("Ровный импульс"))
                .andExpect(jsonPath(
                        "$.expedition.completionRecap.decisions[0]"
                                + ".pilotExperienceGained"
                ).value(48))
                .andExpect(jsonPath(
                        "$.expedition.completionRecap.decisions[0].petName"
                ).value("Искра из записи"))
                .andExpect(jsonPath(
                        "$.expedition.completionRecap.decisions[0]"
                                + ".materialReward.itemName"
                ).value("Эхо-нити из записи"))
                .andExpect(jsonPath(
                        "$.expedition.completionRecap.decisions[0]"
                                + ".materialReward.quantity"
                ).value(2))
                .andExpect(jsonPath(
                        "$.expedition.completionRecap.finalDecision.eventId"
                ).value(StarterExpeditionContent.SECOND_EVENT_ID))
                .andExpect(jsonPath(
                        "$.expedition.completionRecap.finalDecision.eventTitle"
                ).value("Сердце маяка из записи"))
                .andExpect(jsonPath(
                        "$.expedition.completionRecap.finalDecision.choiceId"
                ).value("stabilize-core"))
                .andExpect(jsonPath(
                        "$.expedition.completionRecap.finalDecision.choiceTitle"
                ).value("Стабилизировать ядро"))
                .andExpect(jsonPath(
                        "$.expedition.completionRecap.finalDecision.outcomeTitle"
                ).value("Ровный импульс"))
                .andExpect(jsonPath(
                        "$.expedition.completionRecap.finalDecision"
                                + ".outcomeSummary"
                ).value("Сохранён финальный маршрут."))
                .andExpect(jsonPath(
                        "$.expedition.completionRecap.finalDecision.resolvedAt"
                ).value("2026-07-25T11:58:00Z"))
                .andExpect(jsonPath(
                        "$.expedition.completionRecap.durationSeconds"
                ).value(1_680))
                .andExpect(jsonPath(
                        "$.expedition.completionRecap.pilotExperienceGained"
                ).value(48))
                .andExpect(jsonPath(
                        "$.expedition.completionRecap"
                                + ".pilotExperienceRewards[0].pilotId"
                ).value("navigator-v1"))
                .andExpect(jsonPath(
                        "$.expedition.completionRecap"
                                + ".pilotExperienceRewards[0].pilotName"
                ).value("Навигатор из записи"))
                .andExpect(jsonPath(
                        "$.expedition.completionRecap"
                                + ".pilotExperienceRewards[0]"
                                + ".experienceGained"
                ).value(48))
                .andExpect(jsonPath(
                        "$.expedition.completionRecap.petBondGained"
                ).value(11))
                .andExpect(jsonPath(
                        "$.expedition.completionRecap.petBondRewards[0].petId"
                ).value("spark-v1"))
                .andExpect(jsonPath(
                        "$.expedition.completionRecap.petBondRewards[0].petName"
                ).value("Искра из записи"))
                .andExpect(jsonPath(
                        "$.expedition.completionRecap.petBondRewards[0]"
                                + ".bondGained"
                ).value(11))
                .andExpect(jsonPath(
                        "$.expedition.completionRecap.materials[0].itemId"
                ).value("echo-thread"))
                .andExpect(jsonPath(
                        "$.expedition.completionRecap.materials[0].itemName"
                ).value("Эхо-нити из записи"))
                .andExpect(jsonPath(
                        "$.expedition.completionRecap.materials[0].quantity"
                ).value(2))
                .andExpect(jsonPath(
                        "$.expedition.journeyChronicle"
                                + ".completedJourneyCount"
                ).value(1))
                .andExpect(jsonPath(
                        "$.expedition.journeyChronicle.decisionCount"
                ).value(1))
                .andExpect(jsonPath(
                        "$.expedition.journeyChronicle.totalDurationSeconds"
                ).value(1_680))
                .andExpect(jsonPath(
                        "$.expedition.journeyChronicle.longestDurationSeconds"
                ).value(1_680))
                .andExpect(jsonPath(
                        "$.expedition.journeyChronicle"
                                + ".pilotExperienceGained"
                ).value(48))
                .andExpect(jsonPath(
                        "$.expedition.journeyChronicle"
                                + ".pilotExperienceRewards[0].pilotId"
                ).value("navigator-v1"))
                .andExpect(jsonPath(
                        "$.expedition.journeyChronicle"
                                + ".pilotExperienceRewards[0].pilotName"
                ).value("Навигатор из записи"))
                .andExpect(jsonPath(
                        "$.expedition.journeyChronicle"
                                + ".pilotExperienceRewards[0]"
                                + ".experienceGained"
                ).value(48))
                .andExpect(jsonPath(
                        "$.expedition.journeyChronicle.petBondGained"
                ).value(11))
                .andExpect(jsonPath(
                        "$.expedition.journeyChronicle.petBondRewards[0].petId"
                ).value("spark-v1"))
                .andExpect(jsonPath(
                        "$.expedition.journeyChronicle.petBondRewards[0]"
                                + ".petName"
                ).value("Искра из записи"))
                .andExpect(jsonPath(
                        "$.expedition.journeyChronicle.petBondRewards[0]"
                                + ".bondGained"
                ).value(11))
                .andExpect(jsonPath(
                        "$.expedition.journeyChronicle.materials[0].itemId"
                ).value("echo-thread"))
                .andExpect(jsonPath(
                        "$.expedition.journeyChronicle.materials[0].itemName"
                ).value("Эхо-нити из записи"))
                .andExpect(jsonPath(
                        "$.expedition.journeyChronicle.materials[0].quantity"
                ).value(2))
                .andExpect(jsonPath(
                        "$.expedition.journeyChronicle"
                                + ".decisionOutcomes[0].eventId"
                ).value(StarterExpeditionContent.SECOND_EVENT_ID))
                .andExpect(jsonPath(
                        "$.expedition.journeyChronicle"
                                + ".decisionOutcomes[0].eventTitle"
                ).value("Сердце маяка из записи"))
                .andExpect(jsonPath(
                        "$.expedition.journeyChronicle"
                                + ".decisionOutcomes[0].choiceId"
                ).value("stabilize-core"))
                .andExpect(jsonPath(
                        "$.expedition.journeyChronicle"
                                + ".decisionOutcomes[0].choiceTitle"
                ).value("Стабилизировать ядро"))
                .andExpect(jsonPath(
                        "$.expedition.journeyChronicle"
                                + ".decisionOutcomes[0].outcomeTitle"
                ).value("Ровный импульс"))
                .andExpect(jsonPath(
                        "$.expedition.journeyChronicle"
                                + ".decisionOutcomes[0].decisionCount"
                ).value(1))
                .andExpect(jsonPath(
                        "$.expedition.journeyChronicle"
                                + ".finaleOutcomes[0].eventId"
                ).value(StarterExpeditionContent.SECOND_EVENT_ID))
                .andExpect(jsonPath(
                        "$.expedition.journeyChronicle"
                                + ".finaleOutcomes[0].eventTitle"
                ).value("Сердце маяка из записи"))
                .andExpect(jsonPath(
                        "$.expedition.journeyChronicle"
                                + ".finaleOutcomes[0].choiceId"
                ).value("stabilize-core"))
                .andExpect(jsonPath(
                        "$.expedition.journeyChronicle"
                                + ".finaleOutcomes[0].choiceTitle"
                ).value("Стабилизировать ядро"))
                .andExpect(jsonPath(
                        "$.expedition.journeyChronicle"
                                + ".finaleOutcomes[0].outcomeTitle"
                ).value("Ровный импульс"))
                .andExpect(jsonPath(
                        "$.expedition.journeyChronicle"
                                + ".finaleOutcomes[0].journeyCount"
                ).value(1));
    }

    @Test
    void shouldReturnRecentCompletedJourneyRecaps() throws Exception {
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
                5,
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
                List.of(new ExpeditionJourneyHistory(
                        2,
                        Instant.parse("2026-07-25T11:30:00Z"),
                        List.of(new ExpeditionJourneyEvent(
                                StarterExpeditionContent.SECOND_EVENT_ID,
                                "Сердце маяка из записи",
                                "stabilize-core",
                                "Стабилизировать ядро",
                                "Ровный импульс",
                                "Второй маршрут сохранён.",
                                48,
                                "navigator-v1",
                                "Навигатор из записи",
                                "spark-v1",
                                "Искра из записи",
                                11,
                                null,
                                Instant.parse("2026-07-25T11:58:00Z")
                        ))
                ))
        );
        DailyGoalPolicyProperties goalProperties =
                new DailyGoalPolicyProperties(
                        "adaptive-median-v1",
                        7,
                        3,
                        6_000,
                        2_000,
                        12_000,
                        5,
                        250
                );
        HomeService service = new HomeService(
                repository,
                new StarterHomeContent(),
                new DailyGoalService(
                        (userId, fromInclusive, toExclusive) -> List.of(),
                        new AdaptiveDailyGoalCalculator(goalProperties),
                        goalProperties
                ),
                content,
                Clock.fixed(
                        Instant.parse("2026-07-25T12:00:00Z"),
                        ZoneOffset.UTC
                )
        );
        MockMvc archiveMockMvc = MockMvcBuilders.standaloneSetup(
                        new HomeController(
                                new HomeQueryFactory(),
                                service,
                                FixedRequestIdentityProvider.user("user-1")
                        )
                )
                .setControllerAdvice(new ApiExceptionHandler())
                .build();

        archiveMockMvc.perform(get("/api/v1/home")
                        .queryParam("localDate", "2026-07-25"))
                .andExpect(status().isOk())
                .andExpect(jsonPath(
                        "$.expedition.recentJourneyRecaps.length()"
                ).value(1))
                .andExpect(jsonPath(
                        "$.expedition.recentJourneyRecaps[0].journeyNumber"
                ).value(2))
                .andExpect(jsonPath(
                        "$.expedition.recentJourneyRecaps[0].decisionCount"
                ).value(1))
                .andExpect(jsonPath(
                        "$.expedition.recentJourneyRecaps[0].durationSeconds"
                ).value(1_680))
                .andExpect(jsonPath(
                        "$.expedition.recentJourneyRecaps[0]"
                                + ".decisions.length()"
                ).value(1))
                .andExpect(jsonPath(
                        "$.expedition.recentJourneyRecaps[0]"
                                + ".decisions[0].eventTitle"
                ).value("Сердце маяка из записи"))
                .andExpect(jsonPath(
                        "$.expedition.recentJourneyRecaps[0]"
                                + ".decisions[0].outcomeSummary"
                ).value("Второй маршрут сохранён."))
                .andExpect(jsonPath(
                        "$.expedition.recentJourneyRecaps[0]"
                                + ".decisions[0].resolvedAt"
                ).value("2026-07-25T11:58:00Z"))
                .andExpect(jsonPath(
                        "$.expedition.recentJourneyRecaps[0]"
                                + ".finalDecision.eventTitle"
                ).value("Сердце маяка из записи"))
                .andExpect(jsonPath(
                        "$.expedition.recentJourneyRecaps[0]"
                                + ".finalDecision.choiceTitle"
                ).value("Стабилизировать ядро"))
                .andExpect(jsonPath(
                        "$.expedition.recentJourneyRecaps[0]"
                                + ".finalDecision.outcomeTitle"
                ).value("Ровный импульс"))
                .andExpect(jsonPath(
                        "$.expedition.recentJourneyRecaps[0]"
                                + ".pilotExperienceGained"
                ).value(48))
                .andExpect(jsonPath(
                        "$.expedition.recentJourneyRecaps[0]"
                                + ".pilotExperienceRewards[0].pilotId"
                ).value("navigator-v1"))
                .andExpect(jsonPath(
                        "$.expedition.recentJourneyRecaps[0]"
                                + ".pilotExperienceRewards[0].pilotName"
                ).value("Навигатор из записи"))
                .andExpect(jsonPath(
                        "$.expedition.recentJourneyRecaps[0]"
                                + ".pilotExperienceRewards[0]"
                                + ".experienceGained"
                ).value(48))
                .andExpect(jsonPath(
                        "$.expedition.recentJourneyRecaps[0].petBondGained"
                ).value(11))
                .andExpect(jsonPath(
                        "$.expedition.recentJourneyRecaps[0]"
                                + ".petBondRewards[0].petId"
                ).value("spark-v1"))
                .andExpect(jsonPath(
                        "$.expedition.recentJourneyRecaps[0]"
                                + ".petBondRewards[0].petName"
                ).value("Искра из записи"))
                .andExpect(jsonPath(
                        "$.expedition.recentJourneyRecaps[0]"
                                + ".petBondRewards[0].bondGained"
                ).value(11));
    }

    @Test
    void shouldRejectInvalidDateWithStableError() throws Exception {
        mockMvc.perform(get("/api/v1/home")
                        .queryParam("localDate", "25.07.2026"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.details.field").value("localDate"))
                .andExpect(jsonPath("$.traceId").isNotEmpty());
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
            public Optional<Instant> findJourneyStartedAt(
                    String userId,
                    String expeditionId,
                    long journeyNumber
            ) {
                return Optional.of(
                        Instant.parse("2026-07-25T11:30:00Z")
                );
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
                return ExpeditionJourneyChronicleTotals.empty();
            }
        };
    }
}
