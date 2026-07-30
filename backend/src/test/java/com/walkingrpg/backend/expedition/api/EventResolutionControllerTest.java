package com.walkingrpg.backend.expedition.api;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;

import com.walkingrpg.backend.expedition.application.EventResolutionCommandFactory;
import com.walkingrpg.backend.expedition.application.EventResolutionService;
import com.walkingrpg.backend.expedition.application.EventResultHandoffProperties;
import com.walkingrpg.backend.expedition.application.StarterExpeditionContent;
import com.walkingrpg.backend.expedition.domain.ExpeditionProgressState;
import com.walkingrpg.backend.expedition.domain.ExpeditionProgressStatus;
import com.walkingrpg.backend.expedition.infrastructure.InMemoryEventResolutionRepository;
import com.walkingrpg.backend.expedition.infrastructure.InMemoryExpeditionRepository;
import com.walkingrpg.backend.inventory.application.InventoryService;
import com.walkingrpg.backend.inventory.infrastructure.InMemoryInventoryRepository;
import com.walkingrpg.backend.progression.application.ProgressionService;
import com.walkingrpg.backend.progression.application.StarterProgressionContent;
import com.walkingrpg.backend.progression.infrastructure.InMemoryProgressionRepository;
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

class EventResolutionControllerTest {

    private static final Instant NOW = Instant.parse("2026-07-26T06:00:00Z");

    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        mockMvc = createMockMvc(new ExpeditionProgressState(
                30,
                30,
                ExpeditionProgressStatus.EVENT_READY,
                StarterExpeditionContent.FIRST_NODE_ID,
                StarterExpeditionContent.FIRST_EVENT_ID,
                1
        ), true);
    }

    @Test
    void shouldResolveFirstEventAndReturnSecondNodeTransition() throws Exception {
        mockMvc.perform(post("/api/v1/events/signal-source-v1/resolve")
                        .header(
                                EventResolutionController.CLIENT_CAPABILITIES_HEADER,
                                EventResolutionController.DURABLE_HANDOFF_CAPABILITY
                        )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "choiceId": "analyze-signal",
                                  "idempotencyKey": "event-resolution-1"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.receiptId").isNotEmpty())
                .andExpect(jsonPath("$.status").value("RESOLVED"))
                .andExpect(jsonPath("$.expeditionStatus").value("IN_PROGRESS"))
                .andExpect(jsonPath("$.choiceId").value("analyze-signal"))
                .andExpect(jsonPath("$.outcomeTitle").value("Карта импульсов"))
                .andExpect(jsonPath("$.pilot.experienceGained").value(40))
                .andExpect(jsonPath("$.pilot.currentExperience").value(60))
                .andExpect(jsonPath("$.pet.bondGained").value(5))
                .andExpect(jsonPath("$.pet.bond").value(15))
                .andExpect(jsonPath("$.material").doesNotExist())
                .andExpect(jsonPath("$.handoffRequired").value(true))
                .andExpect(jsonPath("$.nextNode.nodeId").value("lumen-gate"))
                .andExpect(jsonPath("$.nextNode.name").value("Люминовые ворота"))
                .andExpect(jsonPath("$.serverTime").value("2026-07-26T06:00:00Z"));
    }

    @Test
    void shouldResolveSecondEventAndReturnMaterialReward() throws Exception {
        MockMvc secondEventMockMvc = createMockMvc(new ExpeditionProgressState(
                45,
                45,
                ExpeditionProgressStatus.EVENT_READY,
                StarterExpeditionContent.SECOND_NODE_ID,
                StarterExpeditionContent.SECOND_EVENT_ID,
                3
        ), true);

        secondEventMockMvc.perform(post("/api/v1/events/echo-vault-v1/resolve")
                        .header(
                                EventResolutionController.CLIENT_CAPABILITIES_HEADER,
                                EventResolutionController.DURABLE_HANDOFF_CAPABILITY
                                        + ", other-capability"
                        )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "choiceId": "stabilize-core",
                                  "idempotencyKey": "event-resolution-2"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.expeditionStatus").value("IN_PROGRESS"))
                .andExpect(jsonPath("$.material.itemId").value("lumen-shard"))
                .andExpect(jsonPath("$.material.name").value("Люминовый осколок"))
                .andExpect(jsonPath("$.material.quantityGained").value(2))
                .andExpect(jsonPath("$.material.quantityAfter").value(2))
                .andExpect(jsonPath("$.material.version").value(1))
                .andExpect(jsonPath("$.handoffRequired").value(true))
                .andExpect(jsonPath("$.nextNode.nodeId").value("ash-orbit"))
                .andExpect(jsonPath("$.nextNode.name").value("Пепельная орбита"));
    }

    @Test
    void shouldAutoDeliverResultForClientWithoutHandoffCapability()
            throws Exception {
        mockMvc.perform(post("/api/v1/events/signal-source-v1/resolve")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "choiceId": "analyze-signal",
                                  "idempotencyKey": "legacy-event-resolution"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.receiptId").isNotEmpty())
                .andExpect(jsonPath("$.handoffRequired").value(false));
    }

    @Test
    void shouldIgnoreHandoffCapabilityUntilClusterActivation()
            throws Exception {
        MockMvc inactiveHandoff = createMockMvc(new ExpeditionProgressState(
                30,
                30,
                ExpeditionProgressStatus.EVENT_READY,
                StarterExpeditionContent.FIRST_NODE_ID,
                StarterExpeditionContent.FIRST_EVENT_ID,
                1
        ), false);

        inactiveHandoff.perform(post("/api/v1/events/signal-source-v1/resolve")
                        .header(
                                EventResolutionController.CLIENT_CAPABILITIES_HEADER,
                                EventResolutionController.DURABLE_HANDOFF_CAPABILITY
                        )
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "choiceId": "analyze-signal",
                                  "idempotencyKey": "inactive-handoff"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.receiptId").isNotEmpty())
                .andExpect(jsonPath("$.handoffRequired").value(false));
    }

    @Test
    void shouldRejectUnknownChoiceWithStableValidationError() throws Exception {
        mockMvc.perform(post("/api/v1/events/signal-source-v1/resolve")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "choiceId": "unknown-choice",
                                  "idempotencyKey": "event-resolution-3"
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.details.field").value("choiceId"))
                .andExpect(jsonPath("$.traceId").isNotEmpty());
    }

    private MockMvc createMockMvc(
            ExpeditionProgressState state,
            boolean handoffEnabled
    ) {
        InMemoryExpeditionRepository expeditionRepository =
                new InMemoryExpeditionRepository();
        expeditionRepository.saveState(
                "user-1",
                StarterExpeditionContent.EXPEDITION_ID,
                state,
                NOW
        );
        EventResolutionService service = new EventResolutionService(
                expeditionRepository,
                new InMemoryEventResolutionRepository(),
                new ProgressionService(
                        new InMemoryProgressionRepository(),
                        new StarterProgressionContent()
                ),
                new InventoryService(new InMemoryInventoryRepository()),
                new StarterExpeditionContent(),
                Clock.fixed(NOW, ZoneOffset.UTC)
        );
        EventResolutionController controller = new EventResolutionController(
                new EventResolutionCommandFactory(),
                service,
                new EventResultHandoffProperties(handoffEnabled),
                FixedRequestIdentityProvider.user("user-1")
        );
        return MockMvcBuilders.standaloneSetup(controller)
                .setControllerAdvice(new ApiExceptionHandler())
                .build();
    }
}
