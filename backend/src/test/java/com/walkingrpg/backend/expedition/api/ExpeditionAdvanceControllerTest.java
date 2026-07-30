package com.walkingrpg.backend.expedition.api;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;

import com.walkingrpg.backend.economy.application.EconomyService;
import com.walkingrpg.backend.economy.infrastructure.InMemoryEconomyRepository;
import com.walkingrpg.backend.expedition.application.ExpeditionAdvanceCommandFactory;
import com.walkingrpg.backend.expedition.application.ExpeditionAdvanceService;
import com.walkingrpg.backend.expedition.application.StarterExpeditionContent;
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

class ExpeditionAdvanceControllerTest {

    private static final Instant NOW = Instant.parse("2026-07-25T12:00:00Z");

    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        EconomyService economyService = new EconomyService(new InMemoryEconomyRepository());
        economyService.creditActivityEnergy("user-1", 68, "activity-1", NOW);
        ExpeditionAdvanceService service = new ExpeditionAdvanceService(
                new InMemoryExpeditionRepository(),
                new InMemoryEventResolutionRepository(),
                economyService,
                new StarterExpeditionContent(),
                Clock.fixed(NOW, ZoneOffset.UTC)
        );
        ExpeditionAdvanceController controller = new ExpeditionAdvanceController(
                new ExpeditionAdvanceCommandFactory(),
                service,
                FixedRequestIdentityProvider.user("user-1")
        );
        mockMvc = MockMvcBuilders.standaloneSetup(controller)
                .setControllerAdvice(new ApiExceptionHandler())
                .build();
    }

    @Test
    void shouldSpendEnergyAndUnlockFirstEvent() throws Exception {
        mockMvc.perform(post("/api/v1/expeditions/starter-expedition-v1/advance")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "energyToSpend": 30,
                                  "idempotencyKey": "advance-1"
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.expeditionId").value("starter-expedition-v1"))
                .andExpect(jsonPath("$.energySpent").value(30))
                .andExpect(jsonPath("$.energyBalanceAfter").value(38))
                .andExpect(jsonPath("$.progressAfter").value(30))
                .andExpect(jsonPath("$.status").value("EVENT_READY"))
                .andExpect(jsonPath("$.unlockedEvent.eventId").value("signal-source-v1"))
                .andExpect(jsonPath("$.serverTime").value("2026-07-25T12:00:00Z"));
    }

    @Test
    void shouldReturnStableErrorForInsufficientEnergy() throws Exception {
        EconomyService emptyEconomyService = new EconomyService(
                new InMemoryEconomyRepository()
        );
        ExpeditionAdvanceService emptyWalletService = new ExpeditionAdvanceService(
                new InMemoryExpeditionRepository(),
                new InMemoryEventResolutionRepository(),
                emptyEconomyService,
                new StarterExpeditionContent(),
                Clock.fixed(NOW, ZoneOffset.UTC)
        );
        ExpeditionAdvanceController controller = new ExpeditionAdvanceController(
                new ExpeditionAdvanceCommandFactory(),
                emptyWalletService,
                FixedRequestIdentityProvider.user("unknown-user")
        );
        MockMvc poorUserMockMvc = MockMvcBuilders.standaloneSetup(controller)
                .setControllerAdvice(new ApiExceptionHandler())
                .build();

        poorUserMockMvc.perform(
                        post("/api/v1/expeditions/starter-expedition-v1/advance")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("""
                                        {
                                          "energyToSpend": 10,
                                          "idempotencyKey": "advance-poor"
                                        }
                                        """)
                )
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("INSUFFICIENT_ENERGY"))
                .andExpect(jsonPath("$.details.availableEnergy").value(0))
                .andExpect(jsonPath("$.details.requiredEnergy").value(10))
                .andExpect(jsonPath("$.traceId").isNotEmpty());
    }
}
