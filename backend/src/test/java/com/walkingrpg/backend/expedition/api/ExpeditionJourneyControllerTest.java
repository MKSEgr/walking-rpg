package com.walkingrpg.backend.expedition.api;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;

import com.walkingrpg.backend.expedition.application.ExpeditionJourneyCommandFactory;
import com.walkingrpg.backend.expedition.application.ExpeditionJourneyService;
import com.walkingrpg.backend.expedition.application.StarterExpeditionContent;
import com.walkingrpg.backend.expedition.domain.ExpeditionProgressState;
import com.walkingrpg.backend.expedition.domain.ExpeditionProgressStatus;
import com.walkingrpg.backend.expedition.infrastructure.InMemoryEventResolutionRepository;
import com.walkingrpg.backend.expedition.infrastructure.InMemoryExpeditionRepository;
import com.walkingrpg.backend.security.FixedRequestIdentityProvider;
import com.walkingrpg.backend.shared.api.ApiExceptionHandler;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class ExpeditionJourneyControllerTest {

    private static final Instant NOW = Instant.parse("2026-08-17T06:00:00Z");

    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        InMemoryExpeditionRepository repository =
                new InMemoryExpeditionRepository();
        repository.saveState(
                "journey-user",
                StarterExpeditionContent.EXPEDITION_ID,
                new ExpeditionProgressState(
                        30,
                        30,
                        ExpeditionProgressStatus.COMPLETED,
                        StarterExpeditionContent.FIRST_NODE_ID,
                        StarterExpeditionContent.FIRST_EVENT_ID,
                        4
                ),
                NOW.minusSeconds(30)
        );
        ExpeditionJourneyService service = new ExpeditionJourneyService(
                repository,
                new InMemoryEventResolutionRepository(),
                new StarterExpeditionContent(),
                () -> StarterExpeditionContent.STEADY_STEP_ROUTE_CONTENT_VERSION,
                Clock.fixed(NOW, ZoneOffset.UTC)
        );
        ExpeditionJourneyController controller = new ExpeditionJourneyController(
                new ExpeditionJourneyCommandFactory(),
                service,
                FixedRequestIdentityProvider.user("journey-user")
        );
        mockMvc = MockMvcBuilders.standaloneSetup(controller)
                .setControllerAdvice(new ApiExceptionHandler())
                .build();
    }

    @Test
    void shouldBeginNextJourneyAndReturnAuthoritativeState() throws Exception {
        mockMvc.perform(post(
                        "/api/v1/expeditions/starter-expedition-v1/journeys"
                )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "expectedJourneyNumber": 1,
                                  "idempotencyKey": "journey-key"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.journeyNumber").value(2))
                .andExpect(jsonPath("$.progressAfter").value(0))
                .andExpect(jsonPath("$.requiredEnergy").value(30))
                .andExpect(jsonPath("$.expeditionVersion").value(5))
                .andExpect(jsonPath("$.status").value("IN_PROGRESS"))
                .andExpect(jsonPath("$.currentNodeId").value("outer-beacon"))
                .andExpect(jsonPath("$.serverTime").value(
                        "2026-08-17T06:00:00Z"
                ));
    }

    @Test
    void shouldRejectStaleJourneyNumber() throws Exception {
        mockMvc.perform(post(
                        "/api/v1/expeditions/starter-expedition-v1/journeys"
                )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "expectedJourneyNumber": 2,
                                  "idempotencyKey": "stale-key"
                                }
                                """))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value(
                        "EXPEDITION_JOURNEY_STATE_CONFLICT"
                ))
                .andExpect(jsonPath("$.details.expectedJourneyNumber").value(2))
                .andExpect(jsonPath("$.details.currentJourneyNumber").value(1))
                .andExpect(jsonPath("$.details.status").value("COMPLETED"));
    }
}
