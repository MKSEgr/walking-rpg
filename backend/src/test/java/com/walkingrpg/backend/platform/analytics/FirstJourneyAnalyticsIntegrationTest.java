package com.walkingrpg.backend.platform.analytics;

import java.sql.Connection;
import java.sql.Statement;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import javax.sql.DataSource;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;

@SpringBootTest
@ActiveProfiles("test")
@Testcontainers
@Import(FirstJourneyAnalyticsIntegrationTest.FixedClockConfiguration.class)
class FirstJourneyAnalyticsIntegrationTest {

    private static final Instant START = Instant.parse("2026-07-29T16:00:00Z");
    private static final Instant SKEWED_APPLICATION_TIME = Instant.EPOCH;

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
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private DataSource dataSource;

    @Autowired
    private FirstJourneyAnalyticsService service;

    @BeforeEach
    void setUp() {
        jdbcTemplate.execute("TRUNCATE TABLE app_user CASCADE");
    }

    @Test
    void shouldExposeCohortFunnelTimingsAndBackfillQualitySeparately() {
        addUser("alpha-complete", "alpha-1");
        addUser("alpha-partial", "alpha-1");
        addUser("alpha-backfilled", "alpha-1");
        addUser("alpha-not-started", "alpha-1");
        addUser("outside-complete", "outside");

        addCompleteJourney("alpha-complete", START, "AUTHORITATIVE");
        addMilestone(
                "alpha-partial",
                FirstJourneyMilestone.JOURNEY_STARTED,
                START.plusSeconds(300),
                "AUTHORITATIVE"
        );
        addMilestone(
                "alpha-partial",
                FirstJourneyMilestone.FIRST_ACTIVITY_SYNC,
                START.plusSeconds(360),
                "AUTHORITATIVE"
        );
        addMilestone(
                "alpha-partial",
                FirstJourneyMilestone.PET_SELECTED,
                START.plusSeconds(380),
                "AUTHORITATIVE"
        );
        addCompleteJourney(
                "alpha-backfilled",
                START.plusSeconds(600),
                "BACKFILLED"
        );
        addCompleteJourney(
                "outside-complete",
                START.plusSeconds(900),
                "AUTHORITATIVE"
        );

        Instant observationStartedAt = databaseTime();
        FirstJourneyAnalyticsSnapshot snapshot = service.summary(" alpha-1 ");
        Instant observationFinishedAt = databaseTime();

        assertEquals("alpha-1", snapshot.cohortCode());
        assertEquals(4, snapshot.eligibleUsers());
        assertEquals(3, snapshot.startedUsers());
        assertEquals(1, snapshot.notStartedUsers());
        assertEquals(0.75, snapshot.startRate());
        assertSnapshotBoundary(
                observationStartedAt,
                snapshot.generatedAt(),
                observationFinishedAt
        );
        assertEquals(11, snapshot.dataQuality().authoritativeMilestoneRecords());
        assertEquals(8, snapshot.dataQuality().backfilledMilestoneRecords());

        FirstJourneyStageMetric sync = stage(
                snapshot,
                FirstJourneyMilestone.FIRST_ACTIVITY_SYNC
        );
        assertEquals(3, sync.reachedUsers());
        assertEquals(0, sync.missingFromStartedUsers());
        assertEquals(2, sync.authoritativeReachedUsers());
        assertEquals(2, sync.timedUsers());
        assertEquals(1.0, sync.conversionFromStarted());
        assertEquals(2.0 / 3.0, sync.authoritativeConversionFromStarted());
        assertEquals(45L, sync.medianSecondsFromStart());
        assertEquals(57L, sync.p90SecondsFromStart());

        FirstJourneyStageMetric energy = stage(
                snapshot,
                FirstJourneyMilestone.FIRST_ENERGY
        );
        assertEquals(2, energy.reachedUsers());
        assertEquals(1, energy.missingFromStartedUsers());
        assertEquals(1, energy.authoritativeReachedUsers());
        assertEquals(1, energy.timedUsers());
        assertEquals(2.0 / 3.0, energy.conversionFromStarted());
        assertEquals(1.0 / 3.0, energy.authoritativeConversionFromStarted());
        assertEquals(60L, energy.medianSecondsFromStart());
        assertEquals(60L, energy.p90SecondsFromStart());

        FirstJourneyStageMetric completed = stage(
                snapshot,
                FirstJourneyMilestone.ONBOARDING_COMPLETED
        );
        assertEquals(2, completed.reachedUsers());
        assertEquals(1, completed.timedUsers());
        assertEquals(130L, completed.medianSecondsFromStart());
        assertEquals(130L, completed.p90SecondsFromStart());

        FirstJourneyStageMetric acknowledged = stage(
                snapshot,
                FirstJourneyMilestone.FIRST_EVENT_RESULT_ACKNOWLEDGED
        );
        assertEquals(2, acknowledged.reachedUsers());
        assertEquals(1, acknowledged.missingFromStartedUsers());
        assertEquals(1, acknowledged.authoritativeReachedUsers());
        assertEquals(1, acknowledged.timedUsers());
        assertEquals(2.0 / 3.0, acknowledged.conversionFromStarted());
        assertEquals(
                1.0 / 3.0,
                acknowledged.authoritativeConversionFromStarted()
        );
        assertEquals(140L, acknowledged.medianSecondsFromStart());
        assertEquals(140L, acknowledged.p90SecondsFromStart());
    }

    @Test
    void shouldReturnStableEmptySnapshotWithoutInventingTimings() {
        FirstJourneyAnalyticsSnapshot snapshot = service.summary(null);

        assertNull(snapshot.cohortCode());
        assertEquals(0, snapshot.eligibleUsers());
        assertEquals(0, snapshot.startedUsers());
        assertEquals(0.0, snapshot.startRate());
        for (FirstJourneyStageMetric stage : snapshot.stages()) {
            assertEquals(0, stage.reachedUsers());
            assertEquals(0, stage.timedUsers());
            assertEquals(0.0, stage.conversionFromStarted());
            assertEquals(0.0, stage.authoritativeConversionFromStarted());
            assertNull(stage.medianSecondsFromStart());
            assertNull(stage.p90SecondsFromStart());
        }
    }

    @Test
    void shouldNotTreatResolvedOnboardingAsAcknowledgedDelivery() {
        addUser("resolved-without-ack", "alpha-ack-gap");
        addCompleteJourney(
                "resolved-without-ack",
                START,
                "AUTHORITATIVE"
        );
        jdbcTemplate.update("""
                DELETE FROM first_journey_milestone
                WHERE user_id = 'resolved-without-ack'
                  AND milestone = 'FIRST_EVENT_RESULT_ACKNOWLEDGED'
                """);

        FirstJourneyAnalyticsSnapshot snapshot = service.summary("alpha-ack-gap");

        assertEquals(1, stage(
                snapshot,
                FirstJourneyMilestone.ONBOARDING_COMPLETED
        ).reachedUsers());
        FirstJourneyStageMetric acknowledged = stage(
                snapshot,
                FirstJourneyMilestone.FIRST_EVENT_RESULT_ACKNOWLEDGED
        );
        assertEquals(0, acknowledged.reachedUsers());
        assertEquals(1, acknowledged.missingFromStartedUsers());
        assertEquals(0.0, acknowledged.conversionFromStarted());
        assertEquals(0.0, acknowledged.authoritativeConversionFromStarted());
        assertNull(acknowledged.medianSecondsFromStart());
        assertNull(acknowledged.p90SecondsFromStart());
    }

    @Test
    void shouldExcludeLegacyAutoAcknowledgementFromTiming() {
        addUser("legacy-auto-ack", "alpha-legacy");
        addCompleteJourney("legacy-auto-ack", START, "AUTHORITATIVE");
        jdbcTemplate.update("""
                UPDATE first_journey_milestone
                SET attributes = '{"handoffRequired":false}'::jsonb
                WHERE user_id = 'legacy-auto-ack'
                  AND milestone = 'FIRST_EVENT_RESULT_ACKNOWLEDGED'
                """);

        FirstJourneyStageMetric acknowledged = stage(
                service.summary("alpha-legacy"),
                FirstJourneyMilestone.FIRST_EVENT_RESULT_ACKNOWLEDGED
        );

        assertEquals(1, acknowledged.reachedUsers());
        assertEquals(1, acknowledged.authoritativeReachedUsers());
        assertEquals(1.0, acknowledged.authoritativeConversionFromStarted());
        assertEquals(0, acknowledged.timedUsers());
        assertNull(acknowledged.medianSecondsFromStart());
        assertNull(acknowledged.p90SecondsFromStart());
    }

    @Test
    void shouldReadEveryFunnelStageFromOneDatabaseSnapshot() throws Exception {
        addUser("snapshot-user", "snapshot-cohort");

        FirstJourneyAnalyticsSnapshot duringInsert;
        Instant observationStartedAt;
        Instant firstStatementFinishedAt;
        ExecutorService executor = Executors.newSingleThreadExecutor();
        try (Connection blocker = dataSource.getConnection();
             Statement statement = blocker.createStatement()) {
            blocker.setAutoCommit(false);
            statement.execute("""
                    LOCK TABLE first_journey_milestone
                    IN ACCESS EXCLUSIVE MODE
                    """);

            observationStartedAt = databaseTime();
            Future<FirstJourneyAnalyticsSnapshot> pending =
                    executor.submit(() -> service.summary(null));
            awaitBlockedMilestoneRead();
            firstStatementFinishedAt = databaseTime();

            statement.executeUpdate("""
                    INSERT INTO first_journey_milestone (
                        user_id, milestone, occurred_at, source,
                        attributes, recorded_at
                    ) VALUES (
                        'snapshot-user',
                        'JOURNEY_STARTED',
                        '2026-07-29T16:00:00Z',
                        'AUTHORITATIVE',
                        '{}'::jsonb,
                        '2026-07-29T16:00:00Z'
                    )
                    """);
            blocker.commit();
            duringInsert = pending.get(5, TimeUnit.SECONDS);
        } finally {
            executor.shutdownNow();
            executor.awaitTermination(5, TimeUnit.SECONDS);
        }

        assertEquals(1, duringInsert.eligibleUsers());
        assertEquals(0, duringInsert.startedUsers());
        assertEquals(1, duringInsert.notStartedUsers());
        assertSnapshotBoundary(
                observationStartedAt,
                duringInsert.generatedAt(),
                firstStatementFinishedAt
        );

        FirstJourneyAnalyticsSnapshot afterInsert = service.summary(null);
        assertEquals(1, afterInsert.eligibleUsers());
        assertEquals(1, afterInsert.startedUsers());
        assertEquals(0, afterInsert.notStartedUsers());
    }

    private void addUser(String userId, String cohortCode) {
        Timestamp timestamp = Timestamp.from(START.minusSeconds(60));
        jdbcTemplate.update("""
                INSERT INTO app_user (
                    user_id, created_at, last_seen_at, has_successful_activity_sync
                ) VALUES (?, ?, ?, false)
                """, userId, timestamp, timestamp);
        jdbcTemplate.update("""
                INSERT INTO tester_cohort_member (
                    cohort_code, user_id, status, notes,
                    created_by, created_at, updated_at
                ) VALUES (?, ?, 'ACTIVE', NULL, 'test', ?, ?)
                """, cohortCode, userId, timestamp, timestamp);
    }

    private void addCompleteJourney(String userId, Instant start, String source) {
        addMilestone(
                userId,
                FirstJourneyMilestone.JOURNEY_STARTED,
                start,
                source
        );
        addMilestone(
                userId,
                FirstJourneyMilestone.FIRST_ACTIVITY_SYNC,
                start.plusSeconds(30),
                source
        );
        addMilestone(
                userId,
                FirstJourneyMilestone.PET_SELECTED,
                start.plusSeconds(45),
                source
        );
        addMilestone(
                userId,
                FirstJourneyMilestone.FIRST_ENERGY,
                start.plusSeconds(60),
                source
        );
        addMilestone(
                userId,
                FirstJourneyMilestone.FIRST_NODE_REACHED,
                start.plusSeconds(90),
                source
        );
        addMilestone(
                userId,
                FirstJourneyMilestone.FIRST_EVENT_RESOLVED,
                start.plusSeconds(120),
                source
        );
        addMilestone(
                userId,
                FirstJourneyMilestone.ONBOARDING_COMPLETED,
                start.plusSeconds(130),
                source
        );
        addMilestone(
                userId,
                FirstJourneyMilestone.FIRST_EVENT_RESULT_ACKNOWLEDGED,
                start.plusSeconds(140),
                source,
                source.equals("AUTHORITATIVE")
                        ? "{\"handoffRequired\":true}"
                        : "{\"handoffRequired\":false}"
        );
    }

    private void addMilestone(
            String userId,
            FirstJourneyMilestone milestone,
            Instant occurredAt,
            String source
    ) {
        addMilestone(userId, milestone, occurredAt, source, "{}");
    }

    private void addMilestone(
            String userId,
            FirstJourneyMilestone milestone,
            Instant occurredAt,
            String source,
            String attributes
    ) {
        jdbcTemplate.update("""
                INSERT INTO first_journey_milestone (
                    user_id, milestone, occurred_at, source,
                    attributes, recorded_at
                ) VALUES (?, ?, ?, ?, ?::jsonb, ?)
                """,
                userId,
                milestone.name(),
                Timestamp.from(occurredAt),
                source,
                attributes,
                Timestamp.from(occurredAt)
        );
    }

    private FirstJourneyStageMetric stage(
            FirstJourneyAnalyticsSnapshot snapshot,
            FirstJourneyMilestone milestone
    ) {
        return snapshot.stages().stream()
                .filter(stage -> stage.milestone() == milestone)
                .findFirst()
                .orElseThrow();
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
            Instant generatedAt,
            Instant latest
    ) {
        assertFalse(generatedAt.isBefore(earliest));
        assertFalse(generatedAt.isAfter(latest));
    }

    private void awaitBlockedMilestoneRead() throws Exception {
        long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(5);
        while (System.nanoTime() < deadline) {
            Integer blocked = jdbcTemplate.queryForObject("""
                    SELECT count(*)
                    FROM pg_stat_activity
                    WHERE datname = current_database()
                      AND wait_event_type = 'Lock'
                      AND query LIKE '%first_journey_milestone started%'
                    """, Integer.class);
            if (blocked != null && blocked > 0) {
                return;
            }
            Thread.sleep(25);
        }
        throw new IllegalStateException(
                "Analytics query did not reach the blocked milestone read"
        );
    }

    @TestConfiguration(proxyBeanMethods = false)
    static class FixedClockConfiguration {

        @Bean
        @Primary
        Clock firstJourneyAnalyticsClock() {
            return Clock.fixed(SKEWED_APPLICATION_TIME, ZoneOffset.UTC);
        }
    }
}
