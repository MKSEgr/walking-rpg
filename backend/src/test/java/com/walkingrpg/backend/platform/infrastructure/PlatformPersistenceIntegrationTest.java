package com.walkingrpg.backend.platform.infrastructure;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import javax.sql.DataSource;
import tools.jackson.databind.ObjectMapper;
import com.walkingrpg.backend.activity.application.ActivitySyncService;
import com.walkingrpg.backend.activity.domain.ActivityBucket;
import com.walkingrpg.backend.activity.domain.ActivitySyncCommand;
import com.walkingrpg.backend.activity.domain.ActivitySyncOutcome;
import com.walkingrpg.backend.economy.application.EconomyService;
import com.walkingrpg.backend.expedition.application.EventResultAcknowledgementService;
import com.walkingrpg.backend.expedition.application.EventResolutionService;
import com.walkingrpg.backend.expedition.application.ExpeditionAdvanceService;
import com.walkingrpg.backend.expedition.application.StarterExpeditionContent;
import com.walkingrpg.backend.expedition.domain.EventResolutionCommand;
import com.walkingrpg.backend.expedition.domain.ExpeditionAdvanceCommand;
import com.walkingrpg.backend.platform.api.PlatformCommandRequest;
import com.walkingrpg.backend.platform.api.PlatformCommandResponse;
import com.walkingrpg.backend.platform.application.PlatformAdminService;
import com.walkingrpg.backend.platform.application.PlatformContentCatalog;
import com.walkingrpg.backend.platform.application.PlatformIdempotencyConflictException;
import com.walkingrpg.backend.platform.application.PlatformService;
import com.walkingrpg.backend.platform.payment.PaymentProvider;
import com.walkingrpg.backend.platform.progress.PlatformProgressFacts;
import com.walkingrpg.backend.platform.progress.PlatformProgressFactsProvider;
import com.walkingrpg.backend.progression.application.ProgressionService;
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
import static org.junit.jupiter.api.Assertions.assertFalse;
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
    private PlatformAdminService platformAdminService;

    @Autowired
    private ActivitySyncService activitySyncService;

    @Autowired
    private ExpeditionAdvanceService expeditionAdvanceService;

    @Autowired
    private EventResolutionService eventResolutionService;

    @Autowired
    private EventResultAcknowledgementService acknowledgementService;

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
    private ProgressionService progressionService;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private Clock clock;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private DataSource dataSource;

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
                clock,
                progressionService
        );
        PlatformCommandResponse replayed = restarted.execute("platform-user", request);

        assertEquals(first, replayed);
        assertEquals(1, rowCount("app_user"));
        assertEquals(1, rowCount("roadmap_user_state"));
        assertEquals(1, rowCount("processed_roadmap_command"));
        assertEquals(1, rowCount("platform_event"));
        assertEquals(1, milestoneCount("platform-user", "JOURNEY_STARTED"));
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
    void shouldKeepCompassTelemetryOutOfPersistentStateReconciliation() {
        String userId = "compass-telemetry-state-user";
        platformService.execute(userId, new PlatformCommandRequest(
                "COMPLETE_ONBOARDING_STEP",
                "compass-telemetry-state-seed",
                Map.of("stepId", "welcome")
        ));
        String stateBefore = scalarString("""
                SELECT state_json::text
                FROM roadmap_user_state
                WHERE user_id = 'compass-telemetry-state-user'
                """);
        long versionBefore = scalarLong("""
                SELECT version
                FROM roadmap_user_state
                WHERE user_id = 'compass-telemetry-state-user'
                """);
        Timestamp updatedBefore = jdbcTemplate.queryForObject("""
                SELECT updated_at
                FROM roadmap_user_state
                WHERE user_id = ?
                """, Timestamp.class, userId);
        jdbcTemplate.update("""
                INSERT INTO pet_progress (
                    user_id, pet_id, level, bond, version,
                    created_at, updated_at
                ) VALUES (?, 'spark-v1', 1, 60, 1, ?, ?)
                """, userId, Timestamp.from(NOW), Timestamp.from(NOW));
        PlatformCommandRequest request = new PlatformCommandRequest(
                "RECORD_COMPASS_IMPRESSION",
                "compass-telemetry-state-neutral",
                Map.of(
                        "impression", "RECIPE_READY",
                        "contentVersion", StarterExpeditionContent.CONTENT_VERSION
                )
        );

        PlatformCommandResponse first = platformService.execute(userId, request);
        PlatformCommandResponse replayed = platformService.execute(userId, request);

        assertEquals(first, replayed);
        assertEquals(versionBefore, first.stateVersion());
        assertEquals(stateBefore, scalarString("""
                SELECT state_json::text
                FROM roadmap_user_state
                WHERE user_id = 'compass-telemetry-state-user'
                """));
        assertEquals(versionBefore, scalarLong("""
                SELECT version
                FROM roadmap_user_state
                WHERE user_id = 'compass-telemetry-state-user'
                """));
        assertEquals(updatedBefore, jdbcTemplate.queryForObject("""
                SELECT updated_at
                FROM roadmap_user_state
                WHERE user_id = ?
                """, Timestamp.class, userId));
        assertEquals(2, rowCount("processed_roadmap_command"));
        assertEquals(3, rowCount("platform_event"));
    }

    @Test
    void shouldRecordPetSelectionAndCompletedJourneyOnlyOnce() {
        String userId = "journey-user";
        completeStep(userId, "welcome");
        activitySyncService.synchronize(new ActivitySyncCommand(
                userId,
                "journey-device",
                LocalDate.of(2026, 7, 29),
                ZoneId.of("Europe/Berlin"),
                6_842,
                List.of(),
                null,
                "journey-first-sync",
                "signed-attestation"
        ));
        completeStep(userId, "health-permission");
        completeStep(userId, "first-sync");
        PlatformCommandRequest selection = new PlatformCommandRequest(
                "SELECT_PET",
                "journey-select-moss",
                Map.of("petId", "moss-v1")
        );
        platformService.execute(userId, selection);
        expeditionAdvanceService.advance(new ExpeditionAdvanceCommand(
                userId,
                StarterExpeditionContent.EXPEDITION_ID,
                30,
                "journey-first-advance"
        ));
        completeStep(userId, "first-expedition");
        var event = eventResolutionService.resolve(new EventResolutionCommand(
                userId,
                StarterExpeditionContent.FIRST_EVENT_ID,
                "analyze-signal",
                "journey-first-event"
        ));
        PlatformCommandResponse completed = completeStep(userId, "first-event");

        platformService.execute(userId, selection);
        platformService.execute(userId, new PlatformCommandRequest(
                "COMPLETE_ONBOARDING_STEP",
                "journey-step-first-event",
                Map.of("stepId", "first-event")
        ));

        assertEquals(true, completed.snapshot().userState().get("onboardingComplete"));
        assertEquals(1, milestoneCount(userId, "JOURNEY_STARTED"));
        assertEquals(1, milestoneCount(userId, "FIRST_ACTIVITY_SYNC"));
        assertEquals(1, milestoneCount(userId, "FIRST_ENERGY"));
        assertEquals(1, milestoneCount(userId, "PET_SELECTED"));
        assertEquals(1, milestoneCount(userId, "FIRST_NODE_REACHED"));
        assertEquals(1, milestoneCount(userId, "FIRST_EVENT_RESOLVED"));
        assertEquals(1, milestoneCount(userId, "ONBOARDING_COMPLETED"));
        assertEquals(0, milestoneCount(
                userId,
                "FIRST_EVENT_RESULT_ACKNOWLEDGED"
        ));
        assertEquals("moss-v1", jdbcTemplate.queryForObject("""
                SELECT attributes ->> 'petId'
                FROM first_journey_milestone
                WHERE user_id = ?
                  AND milestone = 'PET_SELECTED'
                """, String.class, userId));

        var acknowledgement = acknowledgementService.acknowledge(
                userId,
                event.receiptId()
        );
        var replayedAcknowledgement = acknowledgementService.acknowledge(
                userId,
                event.receiptId()
        );

        assertEquals(acknowledgement, replayedAcknowledgement);
        assertEquals(1, milestoneCount(
                userId,
                "FIRST_EVENT_RESULT_ACKNOWLEDGED"
        ));
        assertEquals(
                acknowledgement.acknowledgedAt(),
                jdbcTemplate.queryForObject("""
                        SELECT occurred_at
                        FROM first_journey_milestone
                        WHERE user_id = ?
                          AND milestone =
                              'FIRST_EVENT_RESULT_ACKNOWLEDGED'
                        """, Timestamp.class, userId).toInstant()
        );
        assertEquals("AUTHORITATIVE", jdbcTemplate.queryForObject("""
                SELECT source
                FROM first_journey_milestone
                WHERE user_id = ?
                  AND milestone = 'FIRST_EVENT_RESULT_ACKNOWLEDGED'
                """, String.class, userId));
        assertEquals("AUTHORITATIVE", jdbcTemplate.queryForObject("""
                SELECT source
                FROM first_journey_milestone
                WHERE user_id = ?
                  AND milestone = 'ONBOARDING_COMPLETED'
                """, String.class, userId));
    }

    @Test
    void shouldDelayMeasuredCompletionUntilLastAuthoritativeFact() {
        String userId = "marker-only-journey-user";
        completeStep(userId, "welcome");
        completeStep(userId, "health-permission");
        completeStep(userId, "first-sync");
        platformService.execute(userId, new PlatformCommandRequest(
                "SELECT_PET",
                "marker-only-select-moss",
                Map.of("petId", "moss-v1")
        ));
        completeStep(userId, "first-expedition");
        PlatformCommandResponse completed = completeStep(userId, "first-event");

        assertEquals(true, completed.snapshot().userState().get("onboardingComplete"));
        assertEquals(1, milestoneCount(userId, "JOURNEY_STARTED"));
        assertEquals(1, milestoneCount(userId, "PET_SELECTED"));
        assertEquals(0, milestoneCount(userId, "FIRST_ACTIVITY_SYNC"));
        assertEquals(0, milestoneCount(userId, "FIRST_ENERGY"));
        assertEquals(0, milestoneCount(userId, "FIRST_NODE_REACHED"));
        assertEquals(0, milestoneCount(userId, "FIRST_EVENT_RESOLVED"));
        assertEquals(0, milestoneCount(userId, "ONBOARDING_COMPLETED"));

        activitySyncService.synchronize(new ActivitySyncCommand(
                userId,
                "delayed-journey-device",
                LocalDate.of(2026, 7, 29),
                ZoneId.of("Europe/Berlin"),
                6_842,
                List.of(),
                null,
                "delayed-journey-sync",
                "signed-attestation"
        ));
        expeditionAdvanceService.advance(new ExpeditionAdvanceCommand(
                userId,
                StarterExpeditionContent.EXPEDITION_ID,
                30,
                "delayed-journey-advance"
        ));
        eventResolutionService.resolve(new EventResolutionCommand(
                userId,
                StarterExpeditionContent.FIRST_EVENT_ID,
                "analyze-signal",
                "delayed-journey-event"
        ));

        assertEquals(1, milestoneCount(userId, "FIRST_ACTIVITY_SYNC"));
        assertEquals(1, milestoneCount(userId, "FIRST_ENERGY"));
        assertEquals(1, milestoneCount(userId, "FIRST_NODE_REACHED"));
        assertEquals(1, milestoneCount(userId, "FIRST_EVENT_RESOLVED"));
        assertEquals(1, milestoneCount(userId, "ONBOARDING_COMPLETED"));
        assertEquals(0, milestoneCount(
                userId,
                "FIRST_EVENT_RESULT_ACKNOWLEDGED"
        ));
        assertEquals(6, jdbcTemplate.queryForObject("""
                SELECT count(*)
                FROM processed_roadmap_command
                WHERE user_id = ?
                """, Integer.class, userId));
    }

    @Test
    void shouldSerializeConcurrentFinalJourneyFacts() throws Exception {
        String userId = "concurrent-journey-user";
        completeStep(userId, "welcome");
        completeStep(userId, "health-permission");
        completeStep(userId, "first-sync");
        platformService.execute(userId, new PlatformCommandRequest(
                "SELECT_PET",
                "concurrent-select-moss",
                Map.of("petId", "moss-v1")
        ));
        completeStep(userId, "first-expedition");
        completeStep(userId, "first-event");
        Instant firstFactAt = Instant.now(clock)
                .plusSeconds(60)
                .truncatedTo(ChronoUnit.MICROS);
        jdbcTemplate.update("""
                INSERT INTO first_journey_milestone (
                    user_id, milestone, occurred_at, source,
                    attributes, recorded_at
                ) VALUES
                    (?, 'FIRST_ACTIVITY_SYNC', ?, 'AUTHORITATIVE', '{}'::jsonb, ?),
                    (?, 'FIRST_ENERGY', ?, 'AUTHORITATIVE', '{}'::jsonb, ?)
                """,
                userId,
                Timestamp.from(firstFactAt),
                Timestamp.from(firstFactAt),
                userId,
                Timestamp.from(firstFactAt.plusSeconds(1)),
                Timestamp.from(firstFactAt.plusSeconds(1))
        );

        ExecutorService executor = Executors.newSingleThreadExecutor();
        try (Connection firstFact = dataSource.getConnection()) {
            firstFact.setAutoCommit(false);
            recordMilestone(
                    firstFact,
                    userId,
                    "FIRST_NODE_REACHED",
                    firstFactAt.plusSeconds(2)
            );
            recheckCompletion(firstFact, userId);

            Future<?> secondFact = executor.submit(() -> {
                try (Connection connection = dataSource.getConnection()) {
                    connection.setAutoCommit(false);
                    recordMilestone(
                            connection,
                            userId,
                            "FIRST_EVENT_RESOLVED",
                            firstFactAt.plusSeconds(3)
                    );
                    recheckCompletion(connection, userId);
                    connection.commit();
                    return null;
                }
            });

            awaitJourneyCompletionLockWait();
            firstFact.commit();
            secondFact.get(5, TimeUnit.SECONDS);
        } finally {
            executor.shutdownNow();
            executor.awaitTermination(5, TimeUnit.SECONDS);
        }

        assertEquals(1, milestoneCount(userId, "ONBOARDING_COMPLETED"));
        assertEquals(
                firstFactAt.plusSeconds(3),
                jdbcTemplate.queryForObject("""
                        SELECT occurred_at
                        FROM first_journey_milestone
                        WHERE user_id = ?
                          AND milestone = 'ONBOARDING_COMPLETED'
                        """, Timestamp.class, userId).toInstant()
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

    @Test
    void shouldExposeSuccessfulZeroStepSyncAsDurablePlatformFact() {
        ActivitySyncOutcome outcome = activitySyncService.synchronize(
                new ActivitySyncCommand(
                        "zero-step-user",
                        "zero-step-device",
                        LocalDate.of(2026, 7, 27),
                        ZoneId.of("Europe/Berlin"),
                        0,
                        List.of(),
                        null,
                        "zero-step-sync-1",
                        "signed-attestation"
                )
        );

        assertEquals(1, rowCount("processed_activity_sync"));
        assertEquals(1, rowCount("app_device"));
        assertEquals(0, rowCount("activity_sync_state"));

        jdbcTemplate.update("DELETE FROM processed_activity_sync");
        jdbcTemplate.update("DELETE FROM activity_risk_assessment");

        PlatformProgressFacts facts = progressFactsProvider.factsFor("zero-step-user");
        Map<String, Object> userState = platformService
                .getSnapshot("zero-step-user")
                .userState();

        assertEquals(0, outcome.activity().acceptedTotal());
        assertEquals(0, facts.totalAcceptedSteps());
        assertTrue(facts.hasSuccessfulActivitySync());
        assertEquals(true, userState.get("hasSuccessfulActivitySync"));
        assertEquals(0, rowCount("processed_activity_sync"));
        assertEquals(0, rowCount("activity_risk_assessment"));
        assertEquals(1, rowCount("app_device"));
        assertEquals(0, rowCount("activity_sync_state"));
        assertEquals(1, milestoneCount(
                "zero-step-user",
                "FIRST_ACTIVITY_SYNC"
        ));
        assertEquals(0, milestoneCount("zero-step-user", "FIRST_ENERGY"));
    }

    @Test
    void shouldNotTreatPushOnlyDeviceAsSuccessfulActivitySync() {
        platformAdminService.registerPush(
                "push-only-user",
                "push-only-device",
                "ANDROID",
                "FCM",
                "push-only-token"
        );

        PlatformProgressFacts facts = progressFactsProvider.factsFor(
                "push-only-user"
        );
        Boolean marker = jdbcTemplate.queryForObject("""
                SELECT has_successful_activity_sync
                FROM app_user
                WHERE user_id = 'push-only-user'
                """, Boolean.class);

        assertEquals(1, rowCount("app_device"));
        assertEquals(1, rowCount("push_registration"));
        assertFalse(Boolean.TRUE.equals(marker));
        assertFalse(facts.hasSuccessfulActivitySync());
    }

    private void ensureUser(String userId) {
        jdbcTemplate.update(
                "INSERT INTO app_user (user_id, created_at, last_seen_at) VALUES (?, ?, ?)",
                userId,
                Timestamp.from(NOW),
                Timestamp.from(NOW)
        );
    }

    private PlatformCommandResponse completeStep(String userId, String stepId) {
        return platformService.execute(userId, new PlatformCommandRequest(
                "COMPLETE_ONBOARDING_STEP",
                "journey-step-" + stepId,
                Map.of("stepId", stepId)
        ));
    }

    private int rowCount(String table) {
        Integer count = jdbcTemplate.queryForObject(
                "SELECT count(*) FROM " + table,
                Integer.class
        );
        return count == null ? 0 : count;
    }

    private int milestoneCount(String userId, String milestone) {
        Integer count = jdbcTemplate.queryForObject("""
                SELECT count(*)
                FROM first_journey_milestone
                WHERE user_id = ?
                  AND milestone = ?
                """, Integer.class, userId, milestone);
        return count == null ? 0 : count;
    }

    private void recordMilestone(
            Connection connection,
            String userId,
            String milestone,
            Instant occurredAt
    ) throws Exception {
        try (PreparedStatement statement = connection.prepareStatement("""
                SELECT record_first_journey_milestone(
                    ?::varchar,
                    ?::varchar,
                    ?::timestamptz,
                    '{}'::jsonb
                )
                """)) {
            statement.setString(1, userId);
            statement.setString(2, milestone);
            statement.setString(3, occurredAt.toString());
            statement.execute();
        }
    }

    private void recheckCompletion(Connection connection, String userId)
            throws Exception {
        try (PreparedStatement statement = connection.prepareStatement("""
                SELECT record_first_journey_completion_if_ready(?::varchar)
                """)) {
            statement.setString(1, userId);
            statement.execute();
        }
    }

    private void awaitJourneyCompletionLockWait() throws Exception {
        long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(5);
        while (System.nanoTime() < deadline) {
            Integer waiting = jdbcTemplate.queryForObject("""
                    SELECT count(*)
                    FROM pg_stat_activity
                    WHERE datname = current_database()
                      AND wait_event_type = 'Lock'
                      AND lower(wait_event) = 'advisory'
                      AND query LIKE
                          '%record_first_journey_completion_if_ready%'
                    """, Integer.class);
            if (waiting != null && waiting > 0) {
                return;
            }
            Thread.sleep(25);
        }
        throw new IllegalStateException(
                "Concurrent milestone did not wait for completion serialization"
        );
    }

    private long scalarLong(String sql) {
        Long value = jdbcTemplate.queryForObject(sql, Long.class);
        return value == null ? 0 : value;
    }

    private String scalarString(String sql) {
        return jdbcTemplate.queryForObject(sql, String.class);
    }
}
