package com.walkingrpg.backend.platform.api;

import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;

import com.walkingrpg.backend.account.application.AccountDeletedException;
import com.walkingrpg.backend.platform.application.AccountDeletionReceipt;
import com.walkingrpg.backend.platform.application.PlatformAdminService;
import com.walkingrpg.backend.security.FixedRequestIdentityProvider;
import com.walkingrpg.backend.security.FreshAuthenticationRequiredException;
import com.walkingrpg.backend.security.RequestIdentityProvider;
import com.walkingrpg.backend.shared.api.ApiExceptionHandler;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class PlatformAdminControllerTest {

    private PlatformAdminService service;

    @BeforeEach
    void setUp() {
        service = mock(PlatformAdminService.class);
    }

    @Test
    void shouldAcceptAnonymousTelemetryWithoutClientControlledUserId() throws Exception {
        MockMvc mockMvc = mockMvc(FixedRequestIdentityProvider.anonymous());

        mockMvc.perform(post("/api/v1/telemetry/events")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "eventName": "app_started",
                                  "occurredAt": "2026-07-28T06:00:00Z",
                                  "attributes": {"source": "cold-start"}
                                }
                                """))
                .andExpect(status().isAccepted())
                .andExpect(jsonPath("$.accepted").value(true));

        verify(service).recordEvent(
                isNull(),
                eq("app_started"),
                eq(Instant.parse("2026-07-28T06:00:00Z")),
                eq(Map.of("source", "cold-start"))
        );
    }

    @Test
    void shouldAttachAuthenticatedSubjectToTelemetry() throws Exception {
        MockMvc mockMvc = mockMvc(FixedRequestIdentityProvider.user("subject-123"));

        mockMvc.perform(post("/api/v1/telemetry/events")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "eventName": "journal_opened",
                                  "attributes": {}
                                }
                                """))
                .andExpect(status().isAccepted());

        verify(service).recordEvent(
                eq("subject-123"),
                eq("journal_opened"),
                isNull(),
                eq(Map.of())
        );
    }

    @Test
    void shouldUseAuthenticatedSubjectForAccountAndPushOperations() throws Exception {
        MockMvc mockMvc = mockMvc(FixedRequestIdentityProvider.user("subject-123"));
        when(service.exportAccount("subject-123")).thenReturn(Map.of("userId", "subject-123"));
        AccountDeletionReceipt receipt = new AccountDeletionReceipt(
                UUID.fromString("11111111-1111-1111-1111-111111111111"),
                "COMPLETED",
                Instant.parse("2026-07-29T05:00:00Z"),
                Instant.parse("2026-07-29T05:00:00Z"),
                false
        );
        when(service.requestAccountDeletion(
                "subject-123",
                "delete-request-1",
                "DELETE"
        )).thenReturn(receipt);

        mockMvc.perform(post("/api/v1/push/registrations")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "deviceId": "device-7",
                                  "platform": "ios",
                                  "provider": "apns",
                                  "token": "secret-token"
                                }
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.registered").value(true));
        mockMvc.perform(get("/api/v1/account/export"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.userId").value("subject-123"));
        mockMvc.perform(post("/api/v1/account/deletion-requests")
                        .header("Idempotency-Key", "delete-request-1")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "confirmation": "DELETE"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.receiptId")
                        .value("11111111-1111-1111-1111-111111111111"))
                .andExpect(jsonPath("$.status").value("COMPLETED"))
                .andExpect(jsonPath("$.replayed").value(false));

        verify(service).registerPush(
                "subject-123",
                "device-7",
                "ios",
                "apns",
                "secret-token"
        );
        verify(service).exportAccount("subject-123");
        verify(service).requestAccountDeletion(
                "subject-123",
                "delete-request-1",
                "DELETE"
        );
    }

    @Test
    void shouldRejectDeletionRequestWithoutIdempotencyKey() throws Exception {
        MockMvc mockMvc = mockMvc(FixedRequestIdentityProvider.user("subject-123"));

        mockMvc.perform(post("/api/v1/account/deletion-requests")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "confirmation": "DELETE"
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.details.field").value("Idempotency-Key"));
    }

    @Test
    void shouldRejectDeletionWithoutFreshServerVerifiedAuthentication()
            throws Exception {
        RequestIdentityProvider identityProvider = mock(RequestIdentityProvider.class);
        when(identityProvider.requireIdentityForAccountDeletion()).thenThrow(
                new FreshAuthenticationRequiredException(
                        "Требуется свежий вход",
                        Duration.ofMinutes(5)
                )
        );
        MockMvc mockMvc = mockMvc(identityProvider);

        mockMvc.perform(post("/api/v1/account/deletion-requests")
                        .header("Idempotency-Key", "delete-request-1")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "confirmation": "DELETE"
                                }
                                """))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("FRESH_AUTHENTICATION_REQUIRED"))
                .andExpect(jsonPath("$.details.maxAuthenticationAgeSeconds").value(300));
    }

    @Test
    void shouldUseSecurityActorForAdminMutation() throws Exception {
        MockMvc mockMvc = mockMvc(FixedRequestIdentityProvider.admin(
                "admin-subject",
                "release-operator"
        ));
        when(service.updateRemoteConfig(eq("release-operator"), eq("config-v2"), any()))
                .thenReturn(Map.of("version", "config-v2", "active", true));

        mockMvc.perform(put("/api/v1/admin/platform/remote-config")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "version": "config-v2",
                                  "config": {
                                    "backgroundHealthSyncEnabled": false,
                                    "activityRetentionDays": 30,
                                    "seasonId": "season-1",
                                    "weeklyRouteEnergy": 100,
                                    "sandboxPaymentsEnabled": false,
                                    "weeklyRouteEnabled": true
                                  }
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.version").value("config-v2"));

        verify(service).updateRemoteConfig(
                eq("release-operator"),
                eq("config-v2"),
                any()
        );
    }

    @Test
    void shouldReturnAuthenticationErrorWhenIdentityIsMissingFromProtectedOperation()
            throws Exception {
        MockMvc mockMvc = mockMvc(FixedRequestIdentityProvider.anonymous());

        mockMvc.perform(get("/api/v1/account/export"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("AUTHENTICATION_ERROR"));
    }

    @Test
    void shouldReturnGoneWhenADeletedSubjectUsesAnOrdinaryEndpoint() throws Exception {
        RequestIdentityProvider identityProvider = mock(RequestIdentityProvider.class);
        when(identityProvider.requireIdentity()).thenThrow(new AccountDeletedException());
        MockMvc mockMvc = mockMvc(identityProvider);

        mockMvc.perform(get("/api/v1/account/export"))
                .andExpect(status().isGone())
                .andExpect(jsonPath("$.code").value("ACCOUNT_DELETED"));
    }

    private MockMvc mockMvc(RequestIdentityProvider identityProvider) {
        return MockMvcBuilders.standaloneSetup(
                        new PlatformAdminController(service, identityProvider)
                )
                .setControllerAdvice(new ApiExceptionHandler())
                .build();
    }
}
