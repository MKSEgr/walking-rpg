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
import com.walkingrpg.backend.home.domain.HomeRuntimeState;
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
                                        .TRAIL_MEMORY_ROUTE_CONTENT_VERSION
                        ))
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
                .andExpect(jsonPath("$.expedition.status").value("EVENT_READY"))
                .andExpect(jsonPath("$.expedition.unlockedEvent.eventId")
                        .value("signal-source-v1"));
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
