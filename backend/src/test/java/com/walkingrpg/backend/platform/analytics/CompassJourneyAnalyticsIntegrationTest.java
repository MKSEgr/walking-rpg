package com.walkingrpg.backend.platform.analytics;

import java.nio.charset.StandardCharsets;
import java.sql.Connection;
import java.sql.Statement;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import javax.sql.DataSource;
import com.walkingrpg.backend.platform.application.PlatformAdminService;
import com.walkingrpg.backend.platform.application.PlatformValidationException;
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
import static org.junit.jupiter.api.Assertions.assertThrows;

@SpringBootTest
@ActiveProfiles("test")
@Testcontainers
@Import(CompassJourneyAnalyticsIntegrationTest.FixedClockConfiguration.class)
class CompassJourneyAnalyticsIntegrationTest {

    private static final Instant START = Instant.parse("2026-07-30T12:00:00Z");
    private static final Instant SKEWED_APPLICATION_TIME = Instant.EPOCH;
    private static final Instant ROUTE_ACTIVATED_AT = START.minusSeconds(1);
    private static final String COHORT = "compass-beta";

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
    private CompassJourneyAnalyticsService service;

    @Autowired
    private PlatformAdminService adminService;

    @BeforeEach
    void setUp() {
        jdbcTemplate.execute("TRUNCATE TABLE app_user CASCADE");
        stageRouteContent();
        activateRouteContent(ROUTE_ACTIVATED_AT);
    }

    @Test
    void shouldExposeCohortFunnelsWithAuthoritativeFactsAndTimingQuality() {
        addUser("complete", COHORT);
        addUser("partial", COHORT);
        addUser("targets-without-start", COHORT);
        addUser("not-started", COHORT);
        addUser("outside", "outside-cohort");

        addRecipeImpression("complete", "MISSING_MATERIALS", START);
        addRecipeImpression("complete", "READY", START.plusSeconds(10));
        UUID completeItem = addCrafted("complete", START.plusSeconds(60));
        addEquipped("complete", completeItem, START.plusSeconds(120));
        addMirrorReached("complete", START.plusSeconds(200));
        addRouteImpression("complete", "LOCKED", START.plusSeconds(210));
        addRouteImpression("complete", "AVAILABLE", START.plusSeconds(220));
        addRouteChosen("complete", START.plusSeconds(260));
        addRouteCompleted("complete", START.plusSeconds(380));

        addRecipeImpression("partial", "MISSING_MATERIALS", START.plusSeconds(300));
        addCrafted("partial", START.plusSeconds(290));
        addMirrorReached("partial", START.plusSeconds(500));
        addRouteChosen("partial", START.plusSeconds(490));

        UUID noStartItem = addCrafted(
                "targets-without-start",
                START.plusSeconds(700)
        );
        addEquipped(
                "targets-without-start",
                noStartItem,
                START.plusSeconds(710)
        );
        addRouteChosen("targets-without-start", START.plusSeconds(720));
        addRouteCompleted("targets-without-start", START.plusSeconds(730));

        seedCompleteJourney("outside", START.plusSeconds(900));

        Instant observationStartedAt = databaseTime();
        CompassJourneyAnalyticsSnapshot snapshot = service.summary(" compass-beta ");
        Instant observationFinishedAt = databaseTime();

        assertEquals(COHORT, snapshot.cohortCode());
        assertEquals(4, snapshot.eligibleUsers());
        assertEquals(2, snapshot.instrumentedUsers());
        assertEquals(0.5, snapshot.instrumentationRate());
        assertSnapshotBoundary(
                observationStartedAt,
                snapshot.generatedAt(),
                observationFinishedAt
        );

        CompassJourneyFunnel crafting = funnel(
                snapshot,
                CompassJourneyFunnelId.CRAFTING_EQUIPMENT
        );
        assertEquals(CompassJourneyStage.RECIPE_SEEN, crafting.startStage());
        assertEquals(CompassJourneyStageSource.CLIENT_REPORTED, crafting.startSource());
        assertEquals(2, crafting.startedUsers());
        assertEquals(2, crafting.notStartedUsers());
        assertEquals(0.5, crafting.startRate());

        CompassJourneyStageMetric ready = stage(
                crafting,
                CompassJourneyStage.RECIPE_READY_SEEN
        );
        assertEquals(1, ready.reachedUsers());
        assertEquals(1, ready.missingFromStartedUsers());
        assertEquals(1, ready.orderedUsers());
        assertEquals(10L, ready.medianSecondsFromStart());

        CompassJourneyStageMetric crafted = stage(
                crafting,
                CompassJourneyStage.COMPASS_CRAFTED
        );
        assertEquals(CompassJourneyStageSource.AUTHORITATIVE, crafted.source());
        assertEquals(2, crafted.reachedUsers());
        assertEquals(1, crafted.orderedUsers());
        assertEquals(1, crafted.outOfOrderUsers());
        assertEquals(1.0, crafted.conversionFromStarted());
        assertEquals(0.5, crafted.orderedConversionFromStarted());
        assertEquals(60L, crafted.medianSecondsFromStart());
        assertEquals(60L, crafted.p90SecondsFromStart());

        CompassJourneyStageMetric equipped = stage(
                crafting,
                CompassJourneyStage.COMPASS_EQUIPPED
        );
        assertEquals(1, equipped.reachedUsers());
        assertEquals(120L, equipped.medianSecondsFromStart());

        CompassJourneyFunnel route = funnel(
                snapshot,
                CompassJourneyFunnelId.RESONANCE_ROUTE
        );
        assertEquals(CompassJourneyStage.MIRROR_DELTA_REACHED, route.startStage());
        assertEquals(CompassJourneyStageSource.AUTHORITATIVE, route.startSource());
        assertEquals(2, route.startedUsers());
        assertEquals(2, route.notStartedUsers());

        CompassJourneyStageMetric chosen = stage(
                route,
                CompassJourneyStage.RESONANCE_ROUTE_CHOSEN
        );
        assertEquals(2, chosen.reachedUsers());
        assertEquals(1, chosen.orderedUsers());
        assertEquals(1, chosen.outOfOrderUsers());
        assertEquals(60L, chosen.medianSecondsFromStart());

        CompassJourneyStageMetric completed = stage(
                route,
                CompassJourneyStage.RESONANCE_ROUTE_COMPLETED
        );
        assertEquals(1, completed.reachedUsers());
        assertEquals(180L, completed.medianSecondsFromStart());

        assertEquals(5, snapshot.dataQuality().clientReportedStageRecords());
        assertEquals(12, snapshot.dataQuality().authoritativeStageRecords());
        assertEquals(2, snapshot.dataQuality().outOfOrderPairs());
        assertEquals(
                1,
                snapshot.dataQuality().craftingTargetsWithoutStartUsers()
        );
        assertEquals(1, snapshot.dataQuality().routeTargetsWithoutStartUsers());
    }

    @Test
    void shouldReturnStableEmptySnapshotAndValidateCohortCode() {
        CompassJourneyAnalyticsSnapshot snapshot = service.summary("  ");

        assertNull(snapshot.cohortCode());
        assertEquals(0, snapshot.eligibleUsers());
        assertEquals(0, snapshot.instrumentedUsers());
        assertEquals(0.0, snapshot.instrumentationRate());
        for (CompassJourneyFunnel funnel : snapshot.funnels()) {
            assertEquals(0, funnel.startedUsers());
            assertEquals(0.0, funnel.startRate());
            for (CompassJourneyStageMetric stage : funnel.stages()) {
                assertEquals(0, stage.reachedUsers());
                assertEquals(0, stage.orderedUsers());
                assertEquals(0.0, stage.conversionFromStarted());
                assertNull(stage.medianSecondsFromStart());
                assertNull(stage.p90SecondsFromStart());
            }
        }

        PlatformValidationException tooLong = assertThrows(
                PlatformValidationException.class,
                () -> service.summary("x".repeat(65))
        );
        assertEquals("cohortCode", tooLong.field());
    }

    @Test
    void shouldStartRouteFunnelAtV2EligibilityAndExcludeLegacyResolution() {
        addUser("legacy-resolved", COHORT);
        addUser("waiting-at-activation", COHORT);
        addUser("reached-after-activation", COHORT);
        stageRouteContent();

        addMirrorReached(
                "legacy-resolved",
                "chapter-1-v1",
                START.plusSeconds(10)
        );
        addMirrorResolved(
                "legacy-resolved",
                "chapter-1-v1",
                "follow-main-signal",
                START.plusSeconds(50)
        );
        addMirrorReached(
                "waiting-at-activation",
                "chapter-1-v1",
                START.plusSeconds(20)
        );

        CompassJourneyFunnel stagedRoute = funnel(
                service.summary(COHORT),
                CompassJourneyFunnelId.RESONANCE_ROUTE
        );
        assertEquals(0, stagedRoute.startedUsers());

        Instant activatedAt = START.plusSeconds(100);
        activateRouteContent(activatedAt);
        addMirrorReached(
                "reached-after-activation",
                "chapter-1-v2",
                START.plusSeconds(140)
        );
        addRouteChosen("waiting-at-activation", START.plusSeconds(130));
        addRouteChosen("reached-after-activation", START.plusSeconds(170));

        CompassJourneyFunnel route = funnel(
                service.summary(COHORT),
                CompassJourneyFunnelId.RESONANCE_ROUTE
        );
        assertEquals(2, route.startedUsers());
        assertEquals(1, route.notStartedUsers());
        assertEquals(2.0 / 3.0, route.startRate());

        CompassJourneyStageMetric chosen = stage(
                route,
                CompassJourneyStage.RESONANCE_ROUTE_CHOSEN
        );
        assertEquals(2, chosen.reachedUsers());
        assertEquals(2, chosen.orderedUsers());
        assertEquals(0, chosen.outOfOrderUsers());
        assertEquals(30L, chosen.medianSecondsFromStart());
        assertEquals(30L, chosen.p90SecondsFromStart());
    }

    @Test
    void shouldKeepRouteBaselineAcrossSameVersionRepublish() {
        addUser("waiting-republish", COHORT);
        stageRouteContent();
        addMirrorReached(
                "waiting-republish",
                "chapter-1-v1",
                START.plusSeconds(20)
        );
        Instant activatedAt = START.plusSeconds(100);
        activateRouteContent(activatedAt);
        addRouteChosen("waiting-republish", START.plusSeconds(130));

        CompassJourneyFunnel before = funnel(
                service.summary(COHORT),
                CompassJourneyFunnelId.RESONANCE_ROUTE
        );
        assertEquals(1, before.startedUsers());
        assertEquals(
                30L,
                stage(
                        before,
                        CompassJourneyStage.RESONANCE_ROUTE_CHOSEN
                ).medianSecondsFromStart()
        );

        Map<String, Object> published = adminService.publishContent(
                "analytics-test",
                "chapter-1-v2",
                "Повторная публикация того же контента.",
                Map.of(
                        "contentVersion", "chapter-1-v2",
                        "chapterId", "signal-chapter-1",
                        "nodeCount", 19,
                        "topology", "resonance-route-v1"
                )
        );

        assertEquals(SKEWED_APPLICATION_TIME, published.get("createdAt"));
        assertEquals(activatedAt, published.get("activatedAt"));
        assertEquals(
                SKEWED_APPLICATION_TIME,
                jdbcTemplate.queryForObject("""
                        SELECT created_at
                        FROM content_release
                        WHERE content_version = 'chapter-1-v2'
                        """, Timestamp.class).toInstant()
        );
        assertEquals(
                activatedAt,
                jdbcTemplate.queryForObject("""
                        SELECT activated_at
                        FROM content_release
                        WHERE content_version = 'chapter-1-v2'
                        """, Timestamp.class).toInstant()
        );

        CompassJourneyAnalyticsSnapshot after = service.summary(COHORT);
        CompassJourneyFunnel route = funnel(
                after,
                CompassJourneyFunnelId.RESONANCE_ROUTE
        );
        assertEquals(1, route.startedUsers());
        assertEquals(
                30L,
                stage(
                        route,
                        CompassJourneyStage.RESONANCE_ROUTE_CHOSEN
                ).medianSecondsFromStart()
        );
        assertEquals(0, after.dataQuality().routeTargetsWithoutStartUsers());
    }

    @Test
    void shouldReadEveryFunnelStageFromOneDatabaseSnapshot() throws Exception {
        addUser("snapshot-user", "snapshot-cohort");

        CompassJourneyAnalyticsSnapshot duringInsert;
        Instant observationStartedAt;
        Instant firstStatementFinishedAt;
        ExecutorService executor = Executors.newSingleThreadExecutor();
        try (Connection blocker = dataSource.getConnection();
             Statement statement = blocker.createStatement()) {
            blocker.setAutoCommit(false);
            statement.execute("LOCK TABLE platform_event IN ACCESS EXCLUSIVE MODE");

            observationStartedAt = databaseTime();
            Future<CompassJourneyAnalyticsSnapshot> pending =
                    executor.submit(() -> service.summary(null));
            awaitBlockedStageRead();
            firstStatementFinishedAt = databaseTime();

            statement.executeUpdate("""
                    INSERT INTO platform_event (
                        user_id, event_name, occurred_at, attributes, received_at
                    ) VALUES (
                        'snapshot-user',
                        'compass_recipe_impression',
                        '2026-07-30T12:00:00Z',
                        '{
                          "contractVersion":"compass-beta-funnel-v1",
                          "recipeId":"resonance-compass-v1",
                          "status":"READY"
                        }'::jsonb,
                        '2026-07-30T12:00:00Z'
                    )
                    """);
            blocker.commit();
            duringInsert = pending.get(5, TimeUnit.SECONDS);
        } finally {
            executor.shutdownNow();
            executor.awaitTermination(5, TimeUnit.SECONDS);
        }

        assertEquals(1, duringInsert.eligibleUsers());
        assertEquals(0, duringInsert.instrumentedUsers());
        assertSnapshotBoundary(
                observationStartedAt,
                duringInsert.generatedAt(),
                firstStatementFinishedAt
        );
        assertEquals(
                0,
                funnel(
                        duringInsert,
                        CompassJourneyFunnelId.CRAFTING_EQUIPMENT
                ).startedUsers()
        );

        CompassJourneyAnalyticsSnapshot afterInsert = service.summary(null);
        assertEquals(1, afterInsert.instrumentedUsers());
        assertEquals(
                1,
                funnel(
                        afterInsert,
                        CompassJourneyFunnelId.CRAFTING_EQUIPMENT
                ).startedUsers()
        );
    }

    @Test
    void shouldAnchorRetentionGeneratedAtToDatabaseSnapshot() {
        Instant observationStartedAt = databaseTime();
        Map<String, Object> snapshot = adminService.retentionSummary();
        Instant observationFinishedAt = databaseTime();

        assertSnapshotBoundary(
                observationStartedAt,
                (Instant) snapshot.get("generatedAt"),
                observationFinishedAt
        );
    }

    private void seedCompleteJourney(String userId, Instant start) {
        addRecipeImpression(userId, "READY", start);
        UUID item = addCrafted(userId, start.plusSeconds(60));
        addEquipped(userId, item, start.plusSeconds(120));
        addMirrorReached(userId, start.plusSeconds(200));
        addRouteImpression(userId, "AVAILABLE", start.plusSeconds(220));
        addRouteChosen(userId, start.plusSeconds(260));
        addRouteCompleted(userId, start.plusSeconds(380));
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

    private void addRecipeImpression(String userId, String status, Instant occurredAt) {
        Timestamp timestamp = Timestamp.from(occurredAt);
        jdbcTemplate.update("""
                INSERT INTO platform_event (
                    user_id, event_name, occurred_at, attributes, received_at
                ) VALUES (
                    ?, 'compass_recipe_impression', ?,
                    jsonb_build_object(
                        'contractVersion', 'compass-beta-funnel-v1',
                        'contentVersion', 'chapter-1-v2',
                        'recipeId', 'resonance-compass-v1',
                        'status', ?
                    ), ?
                )
                """, userId, timestamp, status, timestamp);
    }

    private void addRouteImpression(
            String userId,
            String availability,
            Instant occurredAt
    ) {
        Timestamp timestamp = Timestamp.from(occurredAt);
        jdbcTemplate.update("""
                INSERT INTO platform_event (
                    user_id, event_name, occurred_at, attributes, received_at
                ) VALUES (
                    ?, 'compass_route_impression', ?,
                    jsonb_build_object(
                        'contractVersion', 'compass-beta-funnel-v1',
                        'contentVersion', 'chapter-1-v2',
                        'eventId', 'mirror-delta-v1',
                        'choiceId', 'follow-resonance',
                        'availability', ?
                    ), ?
                )
                """, userId, timestamp, availability, timestamp);
    }

    private UUID addCrafted(String userId, Instant craftedAt) {
        UUID itemInstanceId = UUID.nameUUIDFromBytes(
                ("compass:" + userId).getBytes(StandardCharsets.UTF_8)
        );
        jdbcTemplate.update("""
                INSERT INTO unique_inventory_item (
                    item_instance_id, user_id, item_id, recipe_id,
                    recipe_version, version, crafted_at
                ) VALUES (
                    ?, ?, 'resonance-compass', 'resonance-compass-v1',
                    '1', 1, ?
                )
                """, itemInstanceId, userId, Timestamp.from(craftedAt));
        return itemInstanceId;
    }

    private void addEquipped(String userId, UUID itemInstanceId, Instant equippedAt) {
        Timestamp timestamp = Timestamp.from(equippedAt);
        jdbcTemplate.update("""
                INSERT INTO processed_equipment_command (
                    user_id, slot_id, idempotency_key, request_fingerprint,
                    content_version, action, changed, slot_name,
                    slot_description, equipment_version, item_instance_id,
                    item_id, item_name, item_description, equipped_at,
                    server_time, created_at
                ) VALUES (
                    ?, 'NAVIGATION', 'analytics-equip', repeat('8', 64),
                    'equipment-v1', 'EQUIP', true, 'Навигационный прибор',
                    'Тестовый слот аналитики.', 1, ?,
                    'resonance-compass', 'Резонансный компас',
                    'Тестовый предмет аналитики.', ?, ?, ?
                )
                """, userId, itemInstanceId, timestamp, timestamp, timestamp);
    }

    private void addMirrorReached(String userId, Instant serverTime) {
        addMirrorReached(userId, "chapter-1-v2", serverTime);
    }

    private void addMirrorReached(
            String userId,
            String contentVersion,
            Instant serverTime
    ) {
        ensureJourneyState(userId);
        Timestamp timestamp = Timestamp.from(serverTime);
        jdbcTemplate.update("""
                INSERT INTO processed_expedition_advance (
                    user_id, expedition_id, idempotency_key, request_fingerprint,
                    content_version, expedition_name, energy_spent,
                    energy_balance_after, economy_version, progress_after,
                    required_energy, expedition_version, expedition_status,
                    current_node_id, current_node_name, event_id,
                    event_title, event_summary, server_time, created_at
                ) VALUES (
                    ?, 'signal-expedition-1', 'analytics-mirror', repeat('7', 64),
                    ?, 'Сигнал', 1, 0, 1, 95, 95, 1,
                    'EVENT_READY', 'mirror-delta', 'Зеркальная дельта',
                    'mirror-delta-v1', 'Зеркальная дельта',
                    'Тестовое событие аналитики.', ?, ?
                )
                """, userId, contentVersion, timestamp, timestamp);
    }

    private void addRouteChosen(String userId, Instant serverTime) {
        addResolution(
                userId,
                "mirror-delta-v1",
                "follow-resonance",
                "analytics-route-chosen",
                serverTime
        );
    }

    private void addRouteCompleted(String userId, Instant serverTime) {
        addResolution(
                userId,
                "resonance-pocket-v1",
                "stabilize-resonance",
                "analytics-route-completed",
                serverTime
        );
    }

    private void addMirrorResolved(
            String userId,
            String contentVersion,
            String choiceId,
            Instant serverTime
    ) {
        addResolution(
                userId,
                "mirror-delta-v1",
                choiceId,
                "analytics-legacy-mirror",
                contentVersion,
                serverTime
        );
    }

    private void addResolution(
            String userId,
            String eventId,
            String choiceId,
            String idempotencyKey,
            Instant serverTime
    ) {
        addResolution(
                userId,
                eventId,
                choiceId,
                idempotencyKey,
                "chapter-1-v2",
                serverTime
        );
    }

    private void addResolution(
            String userId,
            String eventId,
            String choiceId,
            String idempotencyKey,
            String contentVersion,
            Instant serverTime
    ) {
        ensureJourneyState(userId);
        Timestamp timestamp = Timestamp.from(serverTime);
        jdbcTemplate.update("""
                INSERT INTO processed_event_resolution (
                    user_id, expedition_id, event_id, idempotency_key,
                    request_fingerprint, content_version, expedition_status,
                    expedition_version, event_title, resolution_status,
                    choice_id, choice_title, outcome_title, outcome_summary,
                    pilot_id, pilot_name, pilot_level_after,
                    pilot_experience_gained, pilot_experience_after,
                    pilot_next_level_experience, pilot_version,
                    pet_id, pet_name, pet_level_after, pet_bond_gained,
                    pet_bond_after, pet_version, server_time, created_at
                ) VALUES (
                    ?, 'signal-expedition-1', ?, ?, repeat('6', 64),
                    ?, 'IN_PROGRESS', 2,
                    'Событие аналитики', 'RESOLVED', ?, 'Выбор',
                    'Исход', 'Тестовый исход аналитики.',
                    'pilot-1', 'Пилот', 1, 10, 10, 100, 1,
                    'spark-v1', 'Искра', 1, 0, 0, 1, ?, ?
                )
                """,
                userId,
                eventId,
                idempotencyKey,
                contentVersion,
                choiceId,
                timestamp,
                timestamp
        );
    }

    private void stageRouteContent() {
        jdbcTemplate.update("UPDATE content_release SET is_active = false WHERE is_active");
        jdbcTemplate.update("""
                DELETE FROM content_release
                WHERE content_version = 'chapter-1-v2'
                """);
        jdbcTemplate.update("""
                UPDATE content_release
                SET is_active = true
                WHERE content_version = 'chapter-1-v1'
                """);
        jdbcTemplate.update("""
                INSERT INTO content_release (
                    content_version,
                    release_notes,
                    content_json,
                    is_active,
                    created_by,
                    created_at,
                    activated_at
                ) VALUES (
                    'chapter-1-v2',
                    'Тестовый staged resonance route.',
                    '{"contentVersion":"chapter-1-v2"}'::jsonb,
                    false,
                    'flyway',
                    ?,
                    NULL
                )
                """, Timestamp.from(START.minusSeconds(300)));
    }

    private void activateRouteContent(Instant activatedAt) {
        jdbcTemplate.update("UPDATE content_release SET is_active = false WHERE is_active");
        jdbcTemplate.update("""
                UPDATE content_release
                SET is_active = true,
                    created_by = 'analytics-test',
                    created_at = ?,
                    activated_at = COALESCE(activated_at, ?)
                WHERE content_version = 'chapter-1-v2'
                """,
                Timestamp.from(activatedAt),
                Timestamp.from(activatedAt)
        );
    }

    private void ensureJourneyState(String userId) {
        Timestamp timestamp = Timestamp.from(START.minusSeconds(30));
        jdbcTemplate.update("""
                INSERT INTO expedition_progress (
                    user_id, expedition_id, current_node_id, progress_energy,
                    required_energy, status, unlocked_event_id, version,
                    created_at, updated_at
                ) VALUES (
                    ?, 'signal-expedition-1', 'mirror-delta', 95, 95,
                    'EVENT_READY', 'mirror-delta-v1', 1, ?, ?
                )
                ON CONFLICT (user_id, expedition_id) DO NOTHING
                """, userId, timestamp, timestamp);
        jdbcTemplate.update("""
                INSERT INTO pilot_progress (
                    user_id, pilot_id, level, current_experience,
                    next_level_experience, version, created_at, updated_at
                ) VALUES (?, 'pilot-1', 1, 0, 100, 1, ?, ?)
                ON CONFLICT (user_id, pilot_id) DO NOTHING
                """, userId, timestamp, timestamp);
        jdbcTemplate.update("""
                INSERT INTO pet_progress (
                    user_id, pet_id, level, bond, version, created_at, updated_at
                ) VALUES (?, 'spark-v1', 1, 0, 1, ?, ?)
                ON CONFLICT (user_id, pet_id) DO NOTHING
                """, userId, timestamp, timestamp);
    }

    private CompassJourneyFunnel funnel(
            CompassJourneyAnalyticsSnapshot snapshot,
            CompassJourneyFunnelId funnelId
    ) {
        return snapshot.funnels().stream()
                .filter(funnel -> funnel.funnel() == funnelId)
                .findFirst()
                .orElseThrow();
    }

    private CompassJourneyStageMetric stage(
            CompassJourneyFunnel funnel,
            CompassJourneyStage stage
    ) {
        return funnel.stages().stream()
                .filter(metric -> metric.stage() == stage)
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

    private void awaitBlockedStageRead() throws Exception {
        long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(5);
        while (System.nanoTime() < deadline) {
            Integer blocked = jdbcTemplate.queryForObject("""
                    SELECT count(*)
                    FROM pg_stat_activity
                    WHERE datname = current_database()
                      AND wait_event_type = 'Lock'
                      AND query LIKE '%compass journey stage events%'
                    """, Integer.class);
            if (blocked != null && blocked > 0) {
                return;
            }
            Thread.sleep(25);
        }
        throw new IllegalStateException(
                "Analytics query did not reach the blocked compass stage read"
        );
    }

    @TestConfiguration(proxyBeanMethods = false)
    static class FixedClockConfiguration {

        @Bean
        @Primary
        Clock compassJourneyAnalyticsClock() {
            return Clock.fixed(SKEWED_APPLICATION_TIME, ZoneOffset.UTC);
        }
    }
}
