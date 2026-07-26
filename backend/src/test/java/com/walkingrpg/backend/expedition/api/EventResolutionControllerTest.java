package com.walkingrpg.backend.expedition.api;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;

import com.walkingrpg.backend.expedition.application.EventResolutionCommandFactory;
import com.walkingrpg.backend.expedition.application.EventResolutionService;
import com.walkingrpg.backend.expedition.application.StarterExpeditionContent;
import com.walkingrpg.backend.expedition.domain.ExpeditionProgressState;
import com.walkingrpg.backend.expedition.domain.ExpeditionProgressStatus;
import com.walkingrpg.backend.expedition.infrastructure.InMemoryEventResolutionRepository;
import com.walkingrpg.backend.expedition.infrastructure.InMemoryExpeditionRepository;
import com.walkingrpg.backend.progression.application.ProgressionService;
import com.walkingrpg.backend.progression.application.StarterProgressionContent;
import com.walkingrpg.backend.progression.infrastructure.InMemoryProgressionRepository;
import com.walkingrpg.backend.shared.api.ApiExceptionHandler;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class EventResolutionControllerTest {

    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        InMemoryExpeditionRepository expeditionRepository =
                new InMemoryExpeditionRepository();
        expeditionRepository.saveState(
                "user-1",
                StarterExpeditionContent.EXPEDITION_ID,
                new ExpeditionProgressState(
                        30,
                        30,
                        ExpeditionProgressStatus.EVENT_READY,
                        "outer-beacon",
                        StarterExpeditionContent.EVENT_ID,
                        1
                ),
                Instant.parse("2026-07-26T06:00:00Z")
        );
        EventResolutionService service = new EventResolutionService(
                expeditionRepository,
                new InMemoryEventResolutionRepository(),
                new ProgressionService(
                        new InMemoryProgressionRepository(),
                        new StarterProgressionContent()
                ),
                new StarterExpeditionContent(),
                Clock.fixed(Instant.parse("2026-07-26T06:00:00Z"), ZoneOffset.UTC)
        );
        EventResolutionController controller = new EventResolutionController(
                new EventResolutionCommandFactory(),
                service
        );
        mockMvc = MockMvcBuilders.standaloneSetup(controller)
                .setControllerAdvice(new ApiExceptionHandler())
                .build();
    }

    @Test
    void shouldResolveEventAndReturnPersistentRewards() throws Exception {
        mockMvc.perform(post("/api/v1/events/signal-source-v1/resolve")
                        .header(EventResolutionController.USER_HEADER, "user-1")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "choiceId": "analyze-signal",
                                  "idempotencyKey": "event-resolution-1"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("RESOLVED"))
                .andExpect(jsonPath("$.expeditionStatus").value("COMPLETED"))
                .andExpect(jsonPath("$.choiceId").value("analyze-signal"))
                .andExpect(jsonPath("$.outcomeTitle").value("Карта импульсов"))
                .andExpect(jsonPath("$.pilot.experienceGained").value(40))
                .andExpect(jsonPath("$.pilot.currentExperience").value(60))
                .andExpect(jsonPath("$.pet.bondGained").value(5))
                .andExpect(jsonPath("$.pet.bond").value(15))
                .andExpect(jsonPath("$.serverTime").value("2026-07-26T06:00:00Z"));
    }

    @Test
    void shouldRejectUnknownChoiceWithStableValidationError() throws Exception {
        mockMvc.perform(post("/api/v1/events/signal-source-v1/resolve")
                        .header(EventResolutionController.USER_HEADER, "user-1")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "choiceId": "unknown-choice",
                                  "idempotencyKey": "event-resolution-2"
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.details.field").value("choiceId"))
                .andExpect(jsonPath("$.traceId").isNotEmpty());
    }
}
