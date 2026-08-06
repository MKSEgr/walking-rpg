package com.walkingrpg.backend.home.infrastructure;

import java.math.BigDecimal;
import java.sql.Connection;
import java.sql.Statement;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import javax.sql.DataSource;

import com.walkingrpg.backend.activity.application.ActivitySyncService;
import com.walkingrpg.backend.activity.domain.ActivitySyncCommand;
import com.walkingrpg.backend.expedition.application.ExpeditionAdvanceService;
import com.walkingrpg.backend.expedition.application.StarterExpeditionContent;
import com.walkingrpg.backend.expedition.domain.ExpeditionAdvanceCommand;
import com.walkingrpg.backend.home.api.HomeSnapshotResponse;
import com.walkingrpg.backend.home.application.HomeService;
import com.walkingrpg.backend.home.domain.HomeQuery;
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
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;

@SpringBootTest
@ActiveProfiles("test")
@Testcontainers
class HomeReadIntegrationTest {

    private static final LocalDate ACTIVITY_DATE = LocalDate.of(2026, 7, 25);

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
    private ActivitySyncService activitySyncService;

    @Autowired
    private ExpeditionAdvanceService expeditionService;

    @Autowired
    private HomeService homeService;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private DataSource dataSource;

    @BeforeEach
    void cleanDatabase() {
        jdbcTemplate.update("DELETE FROM inventory_ledger");
        jdbcTemplate.update("DELETE FROM inventory_stack");
        jdbcTemplate.update("DELETE FROM processed_expedition_advance");
        jdbcTemplate.update("DELETE FROM expedition_progress");
        jdbcTemplate.update("DELETE FROM processed_activity_sync");
        jdbcTemplate.update("DELETE FROM economy_ledger");
        jdbcTemplate.update("DELETE FROM activity_sync_state");
        jdbcTemplate.update("DELETE FROM economy_wallet");
        jdbcTemplate.update("DELETE FROM app_device");
        jdbcTemplate.update("DELETE FROM app_user");
    }

    @Test
    void shouldReturnAcceptedStepsCurrentBalanceAndPersistentExpedition() {
        activitySyncService.synchronize(command(6_842));
        expeditionService.advance(new ExpeditionAdvanceCommand(
                "home-user",
                StarterExpeditionContent.EXPEDITION_ID,
                30,
                "home-advance-1"
        ));

        HomeSnapshotResponse snapshot = homeService.getSnapshot(
                new HomeQuery("home-user", ACTIVITY_DATE)
        );

        assertEquals(6_842, snapshot.dailySteps());
        assertEquals(6_000, snapshot.dailyGoal());
        assertEquals("DEFAULT", snapshot.dailyGoalPolicy().source().name());
        assertEquals(38, snapshot.availableEnergy());
        assertEquals(1, snapshot.activityStateVersion());
        assertEquals(2, snapshot.economyVersion());
        assertEquals("Europe/Berlin", snapshot.timeZone());
        assertEquals(
                StarterExpeditionContent.LEGACY_CONTENT_VERSION,
                snapshot.contentVersion()
        );
        assertEquals(30, snapshot.expedition().progress());
        assertEquals(1, snapshot.expedition().version());
        assertEquals("EVENT_READY", snapshot.expedition().status());
        assertNotNull(snapshot.expedition().unlockedEvent());
        assertEquals(1, rowCount("activity_sync_state"));
        assertEquals(1, rowCount("economy_wallet"));
        assertEquals(2, rowCount("economy_ledger"));
        assertEquals(1, rowCount("expedition_progress"));
    }

    @Test
    void shouldKeepWalletAndExpeditionButReturnZeroActivityForAnotherLocalDay() {
        activitySyncService.synchronize(command(6_842));
        expeditionService.advance(new ExpeditionAdvanceCommand(
                "home-user",
                StarterExpeditionContent.EXPEDITION_ID,
                20,
                "home-advance-partial"
        ));

        HomeSnapshotResponse snapshot = homeService.getSnapshot(
                new HomeQuery("home-user", ACTIVITY_DATE.plusDays(1))
        );

        assertEquals(0, snapshot.dailySteps());
        assertEquals(6_000, snapshot.dailyGoal());
        assertEquals("DEFAULT", snapshot.dailyGoalPolicy().source().name());
        assertEquals(48, snapshot.availableEnergy());
        assertEquals(0, snapshot.activityStateVersion());
        assertEquals(2, snapshot.economyVersion());
        assertNull(snapshot.timeZone());
        assertNull(snapshot.lastActivitySyncAt());
        assertEquals(20, snapshot.expedition().progress());
        assertEquals("IN_PROGRESS", snapshot.expedition().status());
    }

    @Test
    void shouldReturnZeroStateForUnknownUserWithoutWritingAnything() {
        HomeSnapshotResponse snapshot = homeService.getSnapshot(
                new HomeQuery("unknown-user", ACTIVITY_DATE)
        );

        assertEquals(0, snapshot.dailySteps());
        assertEquals(6_000, snapshot.dailyGoal());
        assertEquals("DEFAULT", snapshot.dailyGoalPolicy().source().name());
        assertEquals(0, snapshot.availableEnergy());
        assertEquals(0, snapshot.activityStateVersion());
        assertEquals(0, snapshot.economyVersion());
        assertEquals(0, snapshot.expedition().progress());
        assertEquals("IN_PROGRESS", snapshot.expedition().status());
        assertEquals(0, rowCount("app_user"));
        assertEquals(0, rowCount("economy_wallet"));
        assertEquals(0, rowCount("activity_sync_state"));
        assertEquals(0, rowCount("expedition_progress"));
    }

    @Test
    void shouldCalculateAdaptiveGoalFromPreviousSevenLocalDaysOnly() {
        activitySyncService.synchronize(command(
                ACTIVITY_DATE.minusDays(8),
                12_000,
                "goal-outside-window"
        ));
        activitySyncService.synchronize(command(
                ACTIVITY_DATE.minusDays(3),
                2_000,
                "goal-history-1"
        ));
        activitySyncService.synchronize(command(
                ACTIVITY_DATE.minusDays(2),
                3_000,
                "goal-history-2"
        ));
        activitySyncService.synchronize(command(
                ACTIVITY_DATE.minusDays(1),
                4_000,
                "goal-history-3"
        ));
        activitySyncService.synchronize(command(
                ACTIVITY_DATE,
                11_000,
                "goal-current-day"
        ));

        HomeSnapshotResponse snapshot = homeService.getSnapshot(
                new HomeQuery("home-user", ACTIVITY_DATE)
        );

        assertEquals(11_000, snapshot.dailySteps());
        assertEquals(3_250, snapshot.dailyGoal());
        assertEquals("ADAPTIVE", snapshot.dailyGoalPolicy().source().name());
        assertEquals(BigDecimal.valueOf(3_000), snapshot.dailyGoalPolicy().baselineSteps());
        assertEquals(3, snapshot.dailyGoalPolicy().sampleDays());
        assertEquals(6_000, snapshot.dailyGoalPolicy().defaultGoal());
        assertEquals(7, snapshot.dailyGoalPolicy().lookbackDays());
        assertEquals(5, snapshot.dailyGoalPolicy().growthPercent());
        assertEquals(250, snapshot.dailyGoalPolicy().roundingStep());
    }

    @Test
    void shouldProjectSelectedPetIdentityEvolutionAndLegacyFallback() {
        activitySyncService.synchronize(command(1_000));
        jdbcTemplate.update("""
                INSERT INTO roadmap_user_state (
                    user_id,
                    state_json,
                    version,
                    created_at,
                    updated_at
                )
                VALUES (?, ?::jsonb, 1, now(), now())
                """,
                "home-user",
                """
                {
                  "activePetId": "moss-v1",
                  "pets": {
                    "moss-v1": {
                      "level": 2,
                      "bond": 54,
                      "evolutionStage": 1
                    }
                  }
                }
                """
        );

        HomeSnapshotResponse snapshot = homeService.getSnapshot(
                new HomeQuery("home-user", ACTIVITY_DATE)
        );

        assertEquals("moss-v1", snapshot.pet().petId());
        assertEquals("Мох", snapshot.pet().name());
        assertEquals(2, snapshot.pet().level());
        assertEquals(54, snapshot.pet().bond());
        assertEquals(1, snapshot.pet().evolutionStage());

        jdbcTemplate.update("""
                UPDATE roadmap_user_state
                SET state_json = state_json #- '{pets,moss-v1,evolutionStage}',
                    version = version + 1,
                    updated_at = now()
                WHERE user_id = ?
                """, "home-user");

        HomeSnapshotResponse legacySnapshot = homeService.getSnapshot(
                new HomeQuery("home-user", ACTIVITY_DATE)
        );

        assertEquals("moss-v1", legacySnapshot.pet().petId());
        assertEquals(2, legacySnapshot.pet().level());
        assertEquals(54, legacySnapshot.pet().bond());
        assertEquals(0, legacySnapshot.pet().evolutionStage());
    }

    @Test
    void shouldAnchorHomeServerTimeToFirstDatabaseSnapshotStatement()
            throws Exception {
        HomeSnapshotResponse duringConcurrentSync;
        Instant observationStartedAt;
        Instant firstStatementFinishedAt;
        ExecutorService executor = Executors.newSingleThreadExecutor();
        Future<HomeSnapshotResponse> pending = null;
        try (Connection blocker = dataSource.getConnection()) {
            try {
                blocker.setAutoCommit(false);
                try (Statement lock = blocker.createStatement()) {
                    lock.execute(
                            "LOCK TABLE processed_event_resolution "
                                    + "IN ACCESS EXCLUSIVE MODE"
                    );
                }

                observationStartedAt = databaseTime();
                pending = executor.submit(() -> homeService.getSnapshot(
                        new HomeQuery("home-user", ACTIVITY_DATE)
                ));
                awaitBlockedQuery("FROM processed_event_resolution");
                firstStatementFinishedAt = databaseTime();

                activitySyncService.synchronize(command(1_000));
                blocker.commit();
                duringConcurrentSync = pending.get(5, TimeUnit.SECONDS);
            } finally {
                try {
                    blocker.rollback();
                } finally {
                    if (pending != null && !pending.isDone()) {
                        pending.cancel(true);
                    }
                    executor.shutdownNow();
                    executor.awaitTermination(5, TimeUnit.SECONDS);
                }
            }
        }

        assertEquals(0, duringConcurrentSync.dailySteps());
        assertSnapshotBoundary(
                observationStartedAt,
                duringConcurrentSync.serverTime(),
                firstStatementFinishedAt
        );
        assertEquals(
                1_000,
                homeService.getSnapshot(
                        new HomeQuery("home-user", ACTIVITY_DATE)
                ).dailySteps()
        );
    }

    private Instant databaseTime() {
        Timestamp timestamp = jdbcTemplate.queryForObject(
                "SELECT statement_timestamp()",
                Timestamp.class
        );
        if (timestamp == null) {
            throw new IllegalStateException("Database clock returned no timestamp");
        }
        return timestamp.toInstant();
    }

    private void assertSnapshotBoundary(
            Instant earliest,
            Instant serverTime,
            Instant latest
    ) {
        assertFalse(serverTime.isBefore(earliest));
        assertFalse(serverTime.isAfter(latest));
    }

    private void awaitBlockedQuery(String queryFragment) throws Exception {
        long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(5);
        while (System.nanoTime() < deadline) {
            Integer waiting = jdbcTemplate.queryForObject("""
                    SELECT count(*)
                    FROM pg_stat_activity
                    WHERE datname = current_database()
                      AND wait_event_type = 'Lock'
                      AND query LIKE ?
                    """, Integer.class, "%" + queryFragment + "%");
            if (waiting != null && waiting > 0) {
                return;
            }
            Thread.sleep(25);
        }
        throw new IllegalStateException(
                "Expected query did not reach the blocked state: " + queryFragment
        );
    }

    private int rowCount(String table) {
        return jdbcTemplate.queryForObject("SELECT count(*) FROM " + table, Integer.class);
    }

    private ActivitySyncCommand command(long authoritativeTotal) {
        return command(ACTIVITY_DATE, authoritativeTotal, "home-sync-1");
    }

    private ActivitySyncCommand command(
            LocalDate localDate,
            long authoritativeTotal,
            String idempotencyKey
    ) {
        return new ActivitySyncCommand(
                "home-user",
                "home-device",
                localDate,
                ZoneId.of("Europe/Berlin"),
                authoritativeTotal,
                List.of(),
                "cursor-" + localDate,
                idempotencyKey,
                null
        );
    }
}
