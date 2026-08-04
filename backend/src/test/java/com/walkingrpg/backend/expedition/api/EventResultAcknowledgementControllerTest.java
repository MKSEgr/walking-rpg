package com.walkingrpg.backend.expedition.api;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Locale;
import java.util.UUID;

import com.walkingrpg.backend.expedition.application.EventResolutionService;
import com.walkingrpg.backend.expedition.application.EventResultAcknowledgementService;
import com.walkingrpg.backend.expedition.application.StarterExpeditionContent;
import com.walkingrpg.backend.expedition.domain.EventResolutionCommand;
import com.walkingrpg.backend.expedition.domain.EventResolutionResult;
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
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class EventResultAcknowledgementControllerTest {

    private static final Instant RESOLVED_AT =
            Instant.parse("2026-07-26T06:00:00Z");
    private static final Instant ACKNOWLEDGED_AT =
            Instant.parse("2026-07-26T06:01:00Z");

    private MockMvc mockMvc;
    private InMemoryEventResolutionRepository eventRepository;
    private UUID receiptId;

    @BeforeEach
    void setUp() {
        InMemoryExpeditionRepository expeditionRepository =
                new InMemoryExpeditionRepository();
        eventRepository = new InMemoryEventResolutionRepository();
        expeditionRepository.saveState(
                "user-1",
                StarterExpeditionContent.EXPEDITION_ID,
                new ExpeditionProgressState(
                        30,
                        30,
                        ExpeditionProgressStatus.EVENT_READY,
                        StarterExpeditionContent.FIRST_NODE_ID,
                        StarterExpeditionContent.FIRST_EVENT_ID,
                        1
                ),
                RESOLVED_AT
        );
        EventResolutionService resolutionService = new EventResolutionService(
                expeditionRepository,
                eventRepository,
                new ProgressionService(
                        new InMemoryProgressionRepository(),
                        new StarterProgressionContent()
                ),
                new InventoryService(new InMemoryInventoryRepository()),
                new StarterExpeditionContent(),
                Clock.fixed(RESOLVED_AT, ZoneOffset.UTC)
        );
        EventResolutionResult result = resolutionService.resolve(
                new EventResolutionCommand(
                        "user-1",
                        StarterExpeditionContent.FIRST_EVENT_ID,
                        "analyze-signal",
                        "resolve-first"
                )
        );
        receiptId = result.receiptId();

        EventResultAcknowledgementController controller =
                new EventResultAcknowledgementController(
                        new EventResultAcknowledgementService(
                                eventRepository,
                                Clock.fixed(ACKNOWLEDGED_AT, ZoneOffset.UTC)
                        ),
                        FixedRequestIdentityProvider.user("user-1")
                );
        mockMvc = MockMvcBuilders.standaloneSetup(controller)
                .setControllerAdvice(new ApiExceptionHandler())
                .build();
    }

    @Test
    void shouldAcknowledgeReceiptIdempotently() throws Exception {
        String path = "/api/v1/event-results/"
                + receiptId.toString().toUpperCase(Locale.ROOT)
                + "/acknowledge";

        mockMvc.perform(post(path))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.receiptId").value(receiptId.toString()))
                .andExpect(jsonPath("$.eventId").value("signal-source-v1"))
                .andExpect(jsonPath("$.status").value("ACKNOWLEDGED"))
                .andExpect(jsonPath("$.acknowledgedAt")
                        .value("2026-07-26T06:01:00Z"))
                .andExpect(jsonPath("$.serverTime")
                        .value("2026-07-26T06:01:00Z"));

        MockMvc restartedClient = acknowledgementClient(
                "user-1",
                ACKNOWLEDGED_AT.plusSeconds(60)
        );
        restartedClient.perform(post(path))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.acknowledgedAt")
                        .value("2026-07-26T06:01:00Z"))
                .andExpect(jsonPath("$.serverTime")
                        .value("2026-07-26T06:01:00Z"));
    }

    @Test
    void shouldReturnStableNotFoundForUnknownReceipt() throws Exception {
        UUID missing = UUID.fromString("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa");

        mockMvc.perform(post("/api/v1/event-results/" + missing + "/acknowledge"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("EVENT_RESULT_NOT_FOUND"))
                .andExpect(jsonPath("$.details.receiptId")
                        .value(missing.toString()));
    }

    @Test
    void shouldNotAcknowledgeAnotherUsersReceipt() throws Exception {
        MockMvc anotherUsersClient = acknowledgementClient(
                "user-2",
                ACKNOWLEDGED_AT
        );

        anotherUsersClient.perform(post(
                        "/api/v1/event-results/" + receiptId + "/acknowledge"
                ))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("EVENT_RESULT_NOT_FOUND"));
    }

    @Test
    void shouldRejectNonCanonicalReceiptIdsWithStableValidationError()
            throws Exception {
        EventResultAcknowledgementService service = mock(
                EventResultAcknowledgementService.class
        );
        MockMvc validationClient = MockMvcBuilders.standaloneSetup(
                        new EventResultAcknowledgementController(
                                service,
                                FixedRequestIdentityProvider.user("user-1")
                        )
                )
                .setControllerAdvice(new ApiExceptionHandler())
                .build();

        for (String invalidReceiptId : new String[]{"1-1-1-1-1", "not-a-uuid"}) {
            validationClient.perform(post(
                            "/api/v1/event-results/"
                                    + invalidReceiptId
                                    + "/acknowledge"
                    ))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
                    .andExpect(jsonPath("$.details.field")
                            .value("receiptId"));
        }

        verifyNoInteractions(service);
    }

    private MockMvc acknowledgementClient(String userId, Instant now) {
        EventResultAcknowledgementController controller =
                new EventResultAcknowledgementController(
                        new EventResultAcknowledgementService(
                                eventRepository,
                                Clock.fixed(now, ZoneOffset.UTC)
                        ),
                        FixedRequestIdentityProvider.user(userId)
                );
        return MockMvcBuilders.standaloneSetup(controller)
                .setControllerAdvice(new ApiExceptionHandler())
                .build();
    }
}
