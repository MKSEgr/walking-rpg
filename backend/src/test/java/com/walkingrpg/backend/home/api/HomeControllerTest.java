package com.walkingrpg.backend.home.api;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;

import com.walkingrpg.backend.home.application.HomeQueryFactory;
import com.walkingrpg.backend.home.application.HomeService;
import com.walkingrpg.backend.home.application.StarterHomeContent;
import com.walkingrpg.backend.home.domain.HomeRuntimeState;
import com.walkingrpg.backend.home.infrastructure.HomeReadRepository;
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
        HomeReadRepository repository = (userId, localDate) -> new HomeRuntimeState(
                6_842,
                1,
                "Europe/Berlin",
                Instant.parse("2026-07-25T11:55:00Z"),
                68,
                1
        );
        HomeService service = new HomeService(
                repository,
                new StarterHomeContent(),
                Clock.fixed(Instant.parse("2026-07-25T12:00:00Z"), ZoneOffset.UTC)
        );
        HomeController controller = new HomeController(
                new HomeQueryFactory(),
                service
        );
        mockMvc = MockMvcBuilders.standaloneSetup(controller)
                .setControllerAdvice(new ApiExceptionHandler())
                .build();
    }

    @Test
    void shouldReturnProductionHomeSnapshot() throws Exception {
        mockMvc.perform(get("/api/v1/home")
                        .header(HomeController.USER_HEADER, "user-1")
                        .queryParam("localDate", "2026-07-25"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.localDate").value("2026-07-25"))
                .andExpect(jsonPath("$.timeZone").value("Europe/Berlin"))
                .andExpect(jsonPath("$.dailySteps").value(6842))
                .andExpect(jsonPath("$.dailyGoal").value(6000))
                .andExpect(jsonPath("$.availableEnergy").value(68))
                .andExpect(jsonPath("$.activityStateVersion").value(1))
                .andExpect(jsonPath("$.economyVersion").value(1))
                .andExpect(jsonPath("$.contentVersion").value("starter-v1"))
                .andExpect(jsonPath("$.pilot.name").value("Навигатор"))
                .andExpect(jsonPath("$.pet.name").value("Искра"))
                .andExpect(jsonPath("$.expedition.requiredEnergy").value(30));
    }

    @Test
    void shouldRejectInvalidDateWithStableError() throws Exception {
        mockMvc.perform(get("/api/v1/home")
                        .header(HomeController.USER_HEADER, "user-1")
                        .queryParam("localDate", "25.07.2026"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.details.field").value("localDate"))
                .andExpect(jsonPath("$.traceId").isNotEmpty());
    }

    @Test
    void shouldRejectBlankUserHeader() throws Exception {
        mockMvc.perform(get("/api/v1/home")
                        .header(HomeController.USER_HEADER, " ")
                        .queryParam("localDate", "2026-07-25"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
                .andExpect(jsonPath("$.details.field").value("X-User-Id"));
    }
}
