package com.walkingrpg.backend.activity.api;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;

import com.walkingrpg.backend.activity.application.ActivitySyncCommandFactory;
import com.walkingrpg.backend.activity.application.ActivitySyncService;
import com.walkingrpg.backend.activity.domain.ActivitySyncCalculator;
import com.walkingrpg.backend.activity.infrastructure.InMemoryActivitySyncRepository;
import com.walkingrpg.backend.economy.application.EconomyService;
import com.walkingrpg.backend.economy.infrastructure.InMemoryEconomyRepository;
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
                service,
                FixedRequestIdentityProvider.user("user-1", "device-1")
        );
        mockMvc = MockMvcBuilders.standaloneSetup(controller)
                .setControllerAdvice(new ApiExceptionHandler())
                .build();
    }

    @Test
    void shouldSynchronizeAuthoritativeTotalAndReturnWalletSnapshot() throws Exception {
        mockMvc.perform(post("/api/v1/activity/sync")
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
    void shouldRejectMissingOrNullAuthoritativeTotalBeforeCreatingReceipt()
            throws Exception {
        for (String field : List.of("", "\"authoritativeTotal\": null,")) {
            mockMvc.perform(post("/api/v1/activity/sync")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {
                                      "localDate": "2026-07-25",
                                      "timeZone": "Europe/Berlin",
                                      %s
                                      "buckets": [],
                                      "idempotencyKey": "missing-total"
                                    }
                                    """.formatted(field)))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
                    .andExpect(jsonPath("$.details.authoritativeTotal").exists())
                    .andExpect(jsonPath("$.traceId").isNotEmpty());
        }

        mockMvc.perform(post("/api/v1/activity/sync")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "localDate": "2026-07-25",
                                  "timeZone": "Europe/Berlin",
                                  "authoritativeTotal": 100,
                                  "buckets": [],
                                  "idempotencyKey": "missing-total"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.acceptedTotal").value(100))
                .andExpect(jsonPath("$.energyGranted").value(1));
    }

    @Test
    void shouldRejectMissingOrNullBucketStepsBeforeCreatingReceipt()
            throws Exception {
        for (String field : List.of("", ", \"steps\": null")) {
            mockMvc.perform(post("/api/v1/activity/sync")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {
                                      "localDate": "2026-07-25",
                                      "timeZone": "Europe/Berlin",
                                      "authoritativeTotal": 0,
                                      "buckets": [{
                                        "from": "2026-07-25T08:00:00Z",
                                        "to": "2026-07-25T09:00:00Z"%s
                                      }],
                                      "idempotencyKey": "missing-bucket-steps"
                                    }
                                    """.formatted(field)))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
                    .andExpect(jsonPath("$.details['buckets[0].steps']").exists())
                    .andExpect(jsonPath("$.traceId").isNotEmpty());
        }

        mockMvc.perform(post("/api/v1/activity/sync")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "localDate": "2026-07-25",
                                  "timeZone": "Europe/Berlin",
                                  "authoritativeTotal": 0,
                                  "buckets": [{
                                    "from": "2026-07-25T08:00:00Z",
                                    "to": "2026-07-25T09:00:00Z",
                                    "steps": 0
                                  }],
                                  "idempotencyKey": "missing-bucket-steps"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.acceptedTotal").value(0));
    }

    @Test
    void shouldKeepExplicitZeroActivityNumbersValid() throws Exception {
        mockMvc.perform(post("/api/v1/activity/sync")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "localDate": "2026-07-25",
                                  "timeZone": "Europe/Berlin",
                                  "authoritativeTotal": 0,
                                  "buckets": [{
                                    "from": "2026-07-25T08:00:00Z",
                                    "to": "2026-07-25T09:00:00Z",
                                    "steps": 0
                                  }],
                                  "idempotencyKey": "explicit-zero"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.acceptedTotal").value(0))
                .andExpect(jsonPath("$.acceptedDelta").value(0))
                .andExpect(jsonPath("$.energyGranted").value(0));
    }

    @Test
    void shouldRequireExactIntegerActivityJsonNumbersBeforeCreatingReceipt()
            throws Exception {
        for (String invalidTotal : List.of(
                "1.9",
                "\"1\"",
                "9223372036854775808"
        )) {
            mockMvc.perform(post("/api/v1/activity/sync")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {
                                      "localDate": "2026-07-25",
                                      "timeZone": "Europe/Berlin",
                                      "authoritativeTotal": %s,
                                      "buckets": [],
                                      "idempotencyKey": "exact-total"
                                    }
                                    """.formatted(invalidTotal)))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
                    .andExpect(jsonPath("$.traceId").isNotEmpty());
        }

        mockMvc.perform(post("/api/v1/activity/sync")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "localDate": "2026-07-25",
                                  "timeZone": "Europe/Berlin",
                                  "authoritativeTotal": 1.0,
                                  "buckets": [],
                                  "idempotencyKey": "exact-total"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.acceptedTotal").value(1));

        for (String invalidSteps : List.of(
                "0.5",
                "\"0\"",
                "9223372036854775808"
        )) {
            mockMvc.perform(post("/api/v1/activity/sync")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {
                                      "localDate": "2026-07-25",
                                      "timeZone": "Europe/Berlin",
                                      "authoritativeTotal": 1,
                                      "buckets": [{
                                        "from": "2026-07-25T08:00:00Z",
                                        "to": "2026-07-25T09:00:00Z",
                                        "steps": %s
                                      }],
                                      "idempotencyKey": "exact-bucket-steps"
                                    }
                                    """.formatted(invalidSteps)))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
                    .andExpect(jsonPath("$.traceId").isNotEmpty());
        }

        mockMvc.perform(post("/api/v1/activity/sync")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "localDate": "2026-07-25",
                                  "timeZone": "Europe/Berlin",
                                  "authoritativeTotal": 1,
                                  "buckets": [{
                                    "from": "2026-07-25T08:00:00Z",
                                    "to": "2026-07-25T09:00:00Z",
                                    "steps": 0.0
                                  }],
                                  "idempotencyKey": "exact-bucket-steps"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.acceptedTotal").value(1));
    }

    @Test
    void shouldRejectUnknownTimeZoneWithStableErrorBody() throws Exception {
        mockMvc.perform(post("/api/v1/activity/sync")
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

    @Test
    void shouldRejectFixedOffsetOutsideTheIanaTimeZoneRegistry() throws Exception {
        mockMvc.perform(post("/api/v1/activity/sync")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "localDate": "2026-07-26",
                                  "timeZone": "+18:00",
                                  "authoritativeTotal": 100,
                                  "buckets": [],
                                  "idempotencyKey": "sync-offset"
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.details.field").value("timeZone"))
                .andExpect(jsonPath("$.traceId").isNotEmpty());
    }

    @Test
    void shouldRejectFutureLocalDateWithStableErrorBody() throws Exception {
        mockMvc.perform(post("/api/v1/activity/sync")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "localDate": "2026-07-26",
                                  "timeZone": "Europe/Berlin",
                                  "authoritativeTotal": 100,
                                  "buckets": [],
                                  "idempotencyKey": "sync-future"
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.details.field").value("localDate"))
                .andExpect(jsonPath("$.traceId").isNotEmpty());
    }
}
