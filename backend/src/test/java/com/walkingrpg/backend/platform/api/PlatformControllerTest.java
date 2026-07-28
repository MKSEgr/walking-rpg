package com.walkingrpg.backend.platform.api;

import java.time.Instant;
import java.util.List;
import java.util.Map;

import com.walkingrpg.backend.platform.application.PlatformIdempotencyConflictException;
import com.walkingrpg.backend.platform.application.PlatformService;
import com.walkingrpg.backend.platform.application.PlatformStateConflictException;
import com.walkingrpg.backend.platform.application.PlatformValidationException;
import com.walkingrpg.backend.security.FixedRequestIdentityProvider;
import com.walkingrpg.backend.shared.api.ApiExceptionHandler;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class PlatformControllerTest {

    private static final Instant NOW = Instant.parse("2026-07-27T08:30:00Z");

    private PlatformService service;
    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        service = mock(PlatformService.class);
        mockMvc = MockMvcBuilders.standaloneSetup(new PlatformController(
                        service,
                        FixedRequestIdentityProvider.user("user-1")
                ))
                .setControllerAdvice(new ApiExceptionHandler())
                .build();
    }

    @Test
    void shouldReturnPlatformSnapshot() throws Exception {
        when(service.getSnapshot("user-1")).thenReturn(new PlatformSnapshotResponse(
                "chapter-1-v1",
                3,
                Map.of("activePetId", "spark-v1"),
                Map.of("chapterNodes", 18),
                Map.of("weeklyRouteEnabled", true),
                NOW
        ));

        mockMvc.perform(get("/api/v1/platform"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.contentVersion").value("chapter-1-v1"))
                .andExpect(jsonPath("$.stateVersion").value(3))
                .andExpect(jsonPath("$.userState.activePetId").value("spark-v1"))
                .andExpect(jsonPath("$.content.chapterNodes").value(18))
                .andExpect(jsonPath("$.remoteConfig.weeklyRouteEnabled").value(true));
    }

    @Test
    void shouldExecutePlatformCommand() throws Exception {
        PlatformSnapshotResponse snapshot = new PlatformSnapshotResponse(
                "chapter-1-v1",
                1,
                Map.of("completedOnboardingSteps", List.of("welcome")),
                Map.of("chapterNodes", 18),
                Map.of("weeklyRouteEnabled", true),
                NOW
        );
        when(service.execute(eq("user-1"), any())).thenReturn(new PlatformCommandResponse(
                "COMPLETE_ONBOARDING_STEP",
                "welcome-1",
                "Шаг onboarding завершён",
                1,
                snapshot,
                NOW
        ));

        performCommand(
                "COMPLETE_ONBOARDING_STEP",
                "welcome-1",
                "{\"stepId\":\"welcome\"}"
        )
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.commandType").value("COMPLETE_ONBOARDING_STEP"))
                .andExpect(jsonPath("$.idempotencyKey").value("welcome-1"))
                .andExpect(jsonPath("$.snapshot.stateVersion").value(1));
    }

    @Test
    void shouldReturnContentBootstrap() throws Exception {
        when(service.getContentBootstrap()).thenReturn(Map.of(
                "contentVersion", "chapter-1-v1",
                "content", Map.of("chapterNodes", 18),
                "remoteConfig", Map.of("weeklyRouteEnabled", true),
                "serverTime", NOW
        ));

        mockMvc.perform(get("/api/v1/content/bootstrap"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.contentVersion").value("chapter-1-v1"))
                .andExpect(jsonPath("$.content.chapterNodes").value(18));
    }

    @Test
    void shouldRejectInvalidCommandBody() throws Exception {
        mockMvc.perform(post("/api/v1/platform/commands")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "commandType": " ",
                                  "idempotencyKey": "",
                                  "payload": {}
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.details.commandType").exists())
                .andExpect(jsonPath("$.details.idempotencyKey").exists());
    }

    @Test
    void shouldMapPlatformValidationError() throws Exception {
        when(service.execute(eq("user-1"), any())).thenThrow(
                new PlatformValidationException("Неизвестный petId", "petId")
        );

        performCommand("SELECT_PET", "select-pet-1", "{\"petId\":\"missing\"}")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.message").value("Неизвестный petId"))
                .andExpect(jsonPath("$.details.field").value("petId"));
    }

    @Test
    void shouldMapPlatformStateConflictWithDetails() throws Exception {
        when(service.execute(eq("user-1"), any())).thenThrow(
                new PlatformStateConflictException(
                        "Недостаточно связи для эволюции",
                        Map.of("currentBond", 10, "requiredBond", 50)
                )
        );

        performCommand("EVOLVE_PET", "evolve-pet-1", "{\"petId\":\"spark-v1\"}")
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("PLATFORM_STATE_CONFLICT"))
                .andExpect(jsonPath("$.details.currentBond").value(10))
                .andExpect(jsonPath("$.details.requiredBond").value(50));
    }

    @Test
    void shouldMapPlatformIdempotencyConflict() throws Exception {
        when(service.execute(eq("user-1"), any())).thenThrow(
                new PlatformIdempotencyConflictException()
        );

        performCommand("SELECT_PET", "reused-key", "{\"petId\":\"moss-v1\"}")
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("IDEMPOTENCY_CONFLICT"))
                .andExpect(jsonPath("$.details.field").value("idempotencyKey"));
    }

    private org.springframework.test.web.servlet.ResultActions performCommand(
            String commandType,
            String idempotencyKey,
            String payloadJson
    ) throws Exception {
        return mockMvc.perform(post("/api/v1/platform/commands")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                        {
                          "commandType": "%s",
                          "idempotencyKey": "%s",
                          "payload": %s
                        }
                        """.formatted(commandType, idempotencyKey, payloadJson)));
    }
}
