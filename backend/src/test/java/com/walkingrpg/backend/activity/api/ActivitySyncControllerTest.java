package com.walkingrpg.backend.activity.api;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;

import com.walkingrpg.backend.activity.application.ActivitySyncCommandFactory;
import com.walkingrpg.backend.activity.application.ActivitySyncService;
import com.walkingrpg.backend.activity.domain.ActivitySyncCalculator;
import com.walkingrpg.backend.activity.infrastructure.InMemoryActivitySyncRepository;
import com.walkingrpg.backend.economy.application.EconomyService;
import com.walkingrpg.backend.economy.infrastructure.InMemoryEconomyRepository;
import com.walkingrpg.backend.shared.api.ApiExceptionHandler;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class ActivitySyncControllerTest {

    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        ActivitySyncService service = new ActivitySyncService(
                new InMemoryActivitySyncRepository(),
                new ActivitySyncCalculator(),
                new EconomyService(new InMemoryEconomyRepository()),
                Clock.fixed(Instant.parse("2026-07-25T12:00:00Z"), ZoneOffset.UTC)
        );
        ActivitySyncController controller = new ActivitySyncController(
                new ActivitySyncCommandFactory(),
                service
        );
        mockMvc = MockMvcBuilders.standaloneSetup(controller)
                .setControllerAdvice(new ApiExceptionHandler())
                .build();
    }

    @Test
    void shouldSynchronizeAuthoritativeTotalAndReturnWalletSnapshot() throws Exception {
        mockMvc.perform(post("/api/v1/activity/sync")
                        .header(ActivitySyncController.USER_HEADER, "user-1")
                        .header(ActivitySyncController.DEVICE_HEADER, "device-1")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "localDate": "2026-07-25",
                                  "timeZone": "Europe/Berlin",
                                  "authoritativeTotal": 6842,
                                  "buckets": [],
                                  "syncCursor": "cursor-1",
                                  "idempotencyKey": "sync-1",
                                  "attestation": null
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.acceptedTotal").value(6842))
                .andExpect(jsonPath("$.acceptedDelta").value(6842))
                .andExpect(jsonPath("$.energyGranted").value(68))
                .andExpect(jsonPath("$.energyBalanceAfter").value(68))
                .andExpect(jsonPath("$.economyVersion").value(1))
                .andExpect(jsonPath("$.riskStatus").value("ACCEPTED"))
                .andExpect(jsonPath("$.stateVersion").value(1))
                .andExpect(jsonPath("$.serverTime").value("2026-07-25T12:00:00Z"));
    }

    @Test
    void shouldRejectUnknownTimeZoneWithStableErrorBody() throws Exception {
        mockMvc.perform(post("/api/v1/activity/sync")
                        .header(ActivitySyncController.USER_HEADER, "user-1")
                        .header(ActivitySyncController.DEVICE_HEADER, "device-1")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "localDate": "2026-07-25",
                                  "timeZone": "Moon/Base-1",
                                  "authoritativeTotal": 100,
                                  "buckets": [],
                                  "idempotencyKey": "sync-1"
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.details.field").value("timeZone"))
                .andExpect(jsonPath("$.traceId").isNotEmpty());
    }
}
