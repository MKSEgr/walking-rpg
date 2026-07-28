package com.walkingrpg.backend.platform.infrastructure;

import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.Map;

import tools.jackson.databind.ObjectMapper;
import com.walkingrpg.backend.activity.application.ActivitySyncService;
import com.walkingrpg.backend.activity.domain.ActivityBucket;
import com.walkingrpg.backend.activity.domain.ActivitySyncCommand;
import com.walkingrpg.backend.activity.domain.ActivitySyncOutcome;
import com.walkingrpg.backend.economy.application.EconomyService;
import com.walkingrpg.backend.platform.api.PlatformCommandRequest;
import com.walkingrpg.backend.platform.api.PlatformCommandResponse;
import com.walkingrpg.backend.platform.application.PlatformContentCatalog;
import com.walkingrpg.backend.platform.application.PlatformIdempotencyConflictException;
import com.walkingrpg.backend.platform.application.PlatformService;
import com.walkingrpg.backend.platform.payment.PaymentProvider;
import com.walkingrpg.backend.platform.progress.PlatformProgressFactsProvider;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

@SpringBootTest
@ActiveProfiles("test")
@Testcontainers
class PlatformPersistenceIntegrationTest {

    private static final Instant NOW = Instant.parse("2026-07-27T08:30:00Z");

    @Container
    static final PostgreSQLContainer POSTGRES =
            new PostgreSQLContainer("postgres:17-alpine");

    @DynamicPropertySource
    static void configureDatabase(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        registry.add("spring.datasource.username", POSTGRES::getUsername);
        registry.add("spring.datasource.password", POSTGRES::getPassword);
    }

    @Autowired
    private PlatformService platformService;

    @Autowired
    private ActivitySyncService activitySyncService;

    @Autowired
    private PlatformRepository platformRepository;

    @Autowired
    private PlatformContentCatalog contentCatalog;

    @Autowired
    private PlatformProgressFactsProvider progressFactsProvider;

    @Autowired
    private EconomyService economyService;

    @Autowired
    private PaymentProvider paymentProvider;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private Clock clock;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @BeforeEach
    void cleanDatabase() {
        jdbcTemplate.execute("TRUNCATE TABLE app_user CASCADE");
    }

    @Test
    void shouldPersistPlatformStateAndReplayAfterServiceRestart() {
        assertEquals(0, rowCount("app_user"));
        assertEquals(0, platformService.getSnapshot("platform-user").stateVersion());
        assertEquals(0, rowCount("app_user"));

        PlatformCommandRequest request = new PlatformCommandRequest(
                "COMPLETE_ONBOARDING_STEP",
                "welcome-once",
                Map.of("stepId", "welcome")
        );
        PlatformCommandResponse first = platformService.execute("platform-user", request);

        PlatformService restarted = new PlatformService(
                platformRepository,
                contentCatalog,
                progressFactsProvider,
                economyService,
                paymentProvider,
                objectMapper,
                clock
        );
        PlatformCommandResponse replayed = restarted.execute("platform-user", request);

        assertEquals(first, replayed);
        assertEquals(1, rowCount("app_user"));
        assertEquals(1, rowCount("roadmap_user_state"));
        assertEquals(1, rowCount("processed_roadmap_command"));
        assertEquals(1, rowCount("platform_event"));
        assertEquals("welcome", jdbcTemplate.queryForObject("""
                SELECT state_json -> 'completedOnboardingSteps' ->> 0
                FROM roadmap_user_state
                WHERE user_id = 'platform-user'
                """, String.class));

        assertThrows(PlatformIdempotencyConflictException.class, () ->
                restarted.execute("platform-user", new PlatformCommandRequest(
                        "COMPLETE_ONBOARDING_STEP",
                        "welcome-once",
                        Map.of("stepId", "first-sync")
                ))
        );
    }

    @Test
    void shouldDebitWeeklyRouteOnlyOnceAndPersistDerivedAchievement() {
        ensureUser("weekly-user");
        economyService.creditActivityEnergy("weekly-user", 100, "weekly-seed", NOW);
        PlatformCommandRequest request = new PlatformCommandRequest(
                "ADVANCE_WEEKLY_ROUTE",
                "weekly-route-once",
                Map.of("energyToSpend", 100)
        );

        PlatformCommandResponse first = platformService.execute("weekly-user", request);
        PlatformCommandResponse replayed = platformService.execute("weekly-user", request);

        assertEquals(first, replayed);
        assertEquals(0L, scalarLong("""
                SELECT balance
                FROM economy_wallet
                WHERE user_id = 'weekly-user' AND currency_code = 'ENERGY'
                """));
        assertEquals(2, rowCount("economy_ledger"));
        assertEquals(1, rowCount("processed_roadmap_command"));
        assertEquals("100", scalarString("""
                SELECT state_json ->> 'weeklyRouteProgress'
                FROM roadmap_user_state
                WHERE user_id = 'weekly-user'
                """));
        assertEquals("120", scalarString("""
                SELECT state_json ->> 'seasonXp'
                FROM roadmap_user_state
                WHERE user_id = 'weekly-user'
                """));
        assertTrue(Boolean.TRUE.equals(jdbcTemplate.queryForObject("""
                SELECT (state_json -> 'achievements') @> '["weekly-route-complete"]'::jsonb
                FROM roadmap_user_state
                WHERE user_id = 'weekly-user'
                """, Boolean.class)));
    }

    @Test
    void shouldPersistBlockingRiskSignalWithoutRejectingActivityInShadowMode() {
        ActivitySyncCommand command = new ActivitySyncCommand(
                "risk-user",
                "risk-device",
                LocalDate.of(2026, 7, 27),
                ZoneId.of("Europe/Berlin"),
                120_000,
                List.of(new ActivityBucket(NOW.minusSeconds(60), NOW, 120_000)),
                null,
                "risk-sync-1",
                "signed-attestation"
        );

        ActivitySyncOutcome outcome = activitySyncService.synchronize(command);

        assertEquals(120_000, outcome.activity().acceptedDelta());
        assertEquals(1_200, outcome.energyBalanceAfter());
        assertEquals(1, rowCount("activity_risk_assessment"));
        assertEquals("BLOCK", scalarString("""
                SELECT decision
                FROM activity_risk_assessment
                WHERE user_id = 'risk-user'
                """));
        assertEquals(100, scalarLong("""
                SELECT risk_score
                FROM activity_risk_assessment
                WHERE user_id = 'risk-user'
                """));
        assertEquals(1, rowCount("processed_activity_sync"));
        assertEquals(1, rowCount("activity_sync_state"));
    }


    private void ensureUser(String userId) {
        jdbcTemplate.update(
                "INSERT INTO app_user (user_id, created_at, last_seen_at) VALUES (?, ?, ?)",
                userId,
                Timestamp.from(NOW),
                Timestamp.from(NOW)
        );
    }

    private int rowCount(String table) {
        Integer count = jdbcTemplate.queryForObject(
                "SELECT count(*) FROM " + table,
                Integer.class
        );
        return count == null ? 0 : count;
    }

    private long scalarLong(String sql) {
        Long value = jdbcTemplate.queryForObject(sql, Long.class);
        return value == null ? 0 : value;
    }

    private String scalarString(String sql) {
        return jdbcTemplate.queryForObject(sql, String.class);
    }
}
