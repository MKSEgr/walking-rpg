package com.walkingrpg.backend.migration;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.MigrationVersion;
import org.junit.jupiter.api.Test;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;

@Testcontainers
class DurableEventResultHandoffMigrationTest {

    @Container
    static final PostgreSQLContainer POSTGRES =
            new PostgreSQLContainer("postgres:17-alpine");

    @Test
    void shouldAcknowledgeLegacyResultsAndKeepNewReceiptsPending()
            throws Exception {
        migrateTo("9");
        seedLegacyResult();
        migrateTo("10");
        seedPendingResult();

        migrateAllWhileV10WriterIsActive();

        try (Connection connection = connection();
             Statement statement = connection.createStatement()) {
            try (ResultSet result = statement.executeQuery("""
                    SELECT receipt_id, server_time, acknowledged_at
                    FROM processed_event_resolution
                    WHERE user_id = 'handoff-upgrade-user'
                      AND event_id = 'lumen-threshold-v1'
                    """)) {
                result.next();
                assertNotNull(result.getObject("receipt_id"));
                assertEquals(
                        result.getTimestamp("server_time").toInstant(),
                        result.getTimestamp("acknowledged_at").toInstant()
                );
            }

            try (ResultSet result = statement.executeQuery("""
                    SELECT milestone.occurred_at,
                           milestone.source,
                           milestone.attributes ->> 'eventId' AS event_id,
                           milestone.attributes ->> 'deliveryMode'
                               AS delivery_mode
                    FROM first_journey_milestone milestone
                    WHERE milestone.user_id = 'handoff-upgrade-user'
                      AND milestone.milestone =
                          'FIRST_EVENT_RESULT_ACKNOWLEDGED'
                    """)) {
                result.next();
                assertEquals(
                        "2026-07-30T07:30:00Z",
                        result.getTimestamp("occurred_at").toInstant().toString()
                );
                assertEquals("BACKFILLED", result.getString("source"));
                assertEquals("lumen-threshold-v1", result.getString("event_id"));
                assertEquals("LEGACY_AUTO_ACK",
                        result.getString("delivery_mode"));
            }

            try (ResultSet result = statement.executeQuery("""
                    SELECT handoff_required, next_node_id, next_node_name,
                           acknowledged_at
                    FROM processed_event_resolution
                    WHERE user_id = 'handoff-upgrade-user'
                      AND event_id = 'signal-source-v1'
                    """)) {
                result.next();
                assertEquals(true, result.getBoolean("handoff_required"));
                assertEquals("lumen-gate", result.getString("next_node_id"));
                assertEquals("Врата Люмена", result.getString("next_node_name"));
                assertNull(result.getTimestamp("acknowledged_at"));
            }

            assertEquals(0, scalarLong(statement, """
                    SELECT count(*)
                    FROM first_journey_milestone
                    WHERE user_id = 'pending-v10-user'
                      AND milestone =
                          'FIRST_EVENT_RESULT_ACKNOWLEDGED'
                    """));
            try (ResultSet result = statement.executeQuery("""
                    SELECT source,
                           attributes ->> 'deliveryMode' AS delivery_mode
                    FROM first_journey_milestone
                    WHERE user_id = 'acknowledged-v10-user'
                      AND milestone =
                          'FIRST_EVENT_RESULT_ACKNOWLEDGED'
                    """)) {
                result.next();
                assertEquals("BACKFILLED", result.getString("source"));
                assertEquals("DURABLE_ACK", result.getString("delivery_mode"));
            }

            statement.executeUpdate("""
                    UPDATE processed_event_resolution
                    SET acknowledged_at = server_time + interval '3 minutes'
                    WHERE user_id = 'pending-v10-user'
                      AND event_id = 'pending-v10-event-v1'
                      AND acknowledged_at IS NULL
                    """);
            try (ResultSet result = statement.executeQuery("""
                    SELECT source,
                           attributes ->> 'deliveryMode' AS delivery_mode
                    FROM first_journey_milestone
                    WHERE user_id = 'pending-v10-user'
                      AND milestone =
                          'FIRST_EVENT_RESULT_ACKNOWLEDGED'
                    """)) {
                result.next();
                assertEquals("AUTHORITATIVE", result.getString("source"));
                assertEquals("DURABLE_ACK", result.getString("delivery_mode"));
            }

            statement.executeUpdate("""
                    INSERT INTO processed_event_resolution (
                        user_id,
                        expedition_id,
                        event_id,
                        idempotency_key,
                        request_fingerprint,
                        content_version,
                        expedition_status,
                        expedition_version,
                        event_title,
                        resolution_status,
                        choice_id,
                        choice_title,
                        outcome_title,
                        outcome_summary,
                        pilot_id,
                        pilot_name,
                        pilot_level_after,
                        pilot_experience_gained,
                        pilot_experience_after,
                        pilot_next_level_experience,
                        pilot_version,
                        pet_id,
                        pet_name,
                        pet_level_after,
                        pet_bond_gained,
                        pet_bond_after,
                        pet_version,
                        server_time,
                        created_at
                    ) VALUES (
                        'handoff-upgrade-user',
                        'starter-expedition-v1',
                        'rolling-legacy-event-v1',
                        'rolling-legacy-result',
                        repeat('c', 64),
                        'chapter-1-v1',
                        'IN_PROGRESS',
                        4,
                        'Legacy rolling event',
                        'RESOLVED',
                        'legacy-choice',
                        'Legacy choice',
                        'Legacy outcome',
                        'Старый backend не объявляет durable handoff.',
                        'navigator-v1',
                        'Навигатор',
                        1,
                        1,
                        81,
                        100,
                        3,
                        'spark-v1',
                        'Искра',
                        1,
                        1,
                        21,
                        3,
                        '2026-07-30T08:01:00Z',
                        '2026-07-30T08:01:00Z'
                    )
                    """);

            try (ResultSet result = statement.executeQuery("""
                    SELECT receipt_id, handoff_required, server_time,
                           acknowledged_at
                    FROM processed_event_resolution
                    WHERE user_id = 'handoff-upgrade-user'
                      AND event_id = 'rolling-legacy-event-v1'
                    """)) {
                result.next();
                assertNotNull(result.getObject("receipt_id"));
                assertEquals(false, result.getBoolean("handoff_required"));
                assertEquals(
                        result.getTimestamp("server_time").toInstant(),
                        result.getTimestamp("acknowledged_at").toInstant()
                );
            }

            assertEquals(1, scalarLong(statement, """
                    SELECT count(*)
                    FROM processed_event_resolution
                    WHERE user_id = 'handoff-upgrade-user'
                      AND handoff_required
                      AND acknowledged_at IS NULL
                      AND receipt_id IS NOT NULL
                    """));
            assertEquals(3, scalarLong(statement, """
                    SELECT count(*)
                    FROM processed_event_resolution
                    WHERE user_id = 'handoff-upgrade-user'
                      AND NOT handoff_required
                      AND acknowledged_at IS NOT NULL
                    """));

            assertThrows(SQLException.class, () -> statement.executeUpdate(
                    copiedDurableResultSql(
                            "handoff-upgrade-user",
                            "parallel-event-v1",
                            "parallel-event-result",
                            "NULL"
                    )
            ));

            statement.executeUpdate("""
                    UPDATE processed_event_resolution
                    SET acknowledged_at = server_time
                    WHERE user_id = 'handoff-upgrade-user'
                      AND event_id = 'signal-source-v1'
                      AND acknowledged_at IS NULL
                    """);

            assertThrows(SQLException.class, () -> statement.executeUpdate(
                    copiedDurableResultSql(
                            "handoff-upgrade-user",
                            "preacknowledged-event-v1",
                            "preacknowledged-event-result",
                            "server_time + interval '2 minutes'"
                    )
            ));
            assertEquals(0, scalarLong(statement, """
                    SELECT count(*)
                    FROM processed_event_resolution
                    WHERE user_id = 'handoff-upgrade-user'
                      AND event_id = 'preacknowledged-event-v1'
                    """));
        }
    }

    private void migrateTo(String version) {
        Flyway.configure()
                .dataSource(
                        POSTGRES.getJdbcUrl(),
                        POSTGRES.getUsername(),
                        POSTGRES.getPassword()
                )
                .target(MigrationVersion.fromVersion(version))
                .load()
                .migrate();
    }

    private void migrateAll() {
        Flyway.configure()
                .dataSource(
                        POSTGRES.getJdbcUrl(),
                        POSTGRES.getUsername(),
                        POSTGRES.getPassword()
                )
                .load()
                .migrate();
    }

    private void migrateAllWhileV10WriterIsActive() throws Exception {
        ExecutorService executor = Executors.newSingleThreadExecutor();
        try (Connection writer = connection();
             Statement writerStatement = writer.createStatement()) {
            writer.setAutoCommit(false);
            writerStatement.execute("""
                    LOCK TABLE processed_event_resolution
                    IN ROW EXCLUSIVE MODE
                    """);

            Future<?> migration = executor.submit(this::migrateAll);
            awaitPendingV11ResolutionLock();

            assertEquals(0, scalarLong(writerStatement, """
                    SELECT count(*)
                    FROM pg_locks milestone_lock
                    JOIN pg_class milestone_relation
                      ON milestone_relation.oid = milestone_lock.relation
                    WHERE milestone_relation.relname =
                              'first_journey_milestone'
                      AND milestone_lock.granted
                      AND milestone_lock.mode = 'AccessExclusiveLock'
                      AND milestone_lock.pid IN (
                          SELECT pending.pid
                          FROM pg_locks pending
                          JOIN pg_class processed_relation
                            ON processed_relation.oid = pending.relation
                          WHERE processed_relation.relname =
                                    'processed_event_resolution'
                            AND NOT pending.granted
                            AND pending.mode = 'ShareRowExclusiveLock'
                      )
                    """));

            writerStatement.executeUpdate("""
                    INSERT INTO processed_event_resolution (
                        user_id,
                        expedition_id,
                        event_id,
                        idempotency_key,
                        request_fingerprint,
                        content_version,
                        expedition_status,
                        expedition_version,
                        event_title,
                        resolution_status,
                        choice_id,
                        choice_title,
                        outcome_title,
                        outcome_summary,
                        pilot_id,
                        pilot_name,
                        pilot_level_after,
                        pilot_experience_gained,
                        pilot_experience_after,
                        pilot_next_level_experience,
                        pilot_version,
                        pet_id,
                        pet_name,
                        pet_level_after,
                        pet_bond_gained,
                        pet_bond_after,
                        pet_version,
                        server_time,
                        created_at
                    )
                    SELECT
                        user_id,
                        expedition_id,
                        'during-v11-legacy-event-v1',
                        'during-v11-legacy-result',
                        request_fingerprint,
                        content_version,
                        expedition_status,
                        expedition_version,
                        event_title,
                        resolution_status,
                        choice_id,
                        choice_title,
                        outcome_title,
                        outcome_summary,
                        pilot_id,
                        pilot_name,
                        pilot_level_after,
                        pilot_experience_gained,
                        pilot_experience_after,
                        pilot_next_level_experience,
                        pilot_version,
                        pet_id,
                        pet_name,
                        pet_level_after,
                        pet_bond_gained,
                        pet_bond_after,
                        pet_version,
                        server_time + interval '30 seconds',
                        created_at + interval '30 seconds'
                    FROM processed_event_resolution
                    WHERE user_id = 'handoff-upgrade-user'
                      AND event_id = 'signal-source-v1'
                    """);
            writer.commit();

            migration.get(10, TimeUnit.SECONDS);
        } finally {
            executor.shutdownNow();
            executor.awaitTermination(5, TimeUnit.SECONDS);
        }
    }

    private void awaitPendingV11ResolutionLock() throws Exception {
        long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(5);
        while (System.nanoTime() < deadline) {
            try (Connection observer = connection();
                 Statement statement = observer.createStatement()) {
                if (scalarLong(statement, """
                        SELECT count(*)
                        FROM pg_locks pending
                        JOIN pg_class relation
                          ON relation.oid = pending.relation
                        WHERE relation.relname =
                                  'processed_event_resolution'
                          AND NOT pending.granted
                          AND pending.mode = 'ShareRowExclusiveLock'
                        """) > 0) {
                    return;
                }
            }
            Thread.sleep(25);
        }
        throw new AssertionError(
                "V11 did not wait for the active V10 resolution writer"
        );
    }

    private void seedLegacyResult() throws Exception {
        try (Connection connection = connection();
             Statement statement = connection.createStatement()) {
            statement.executeUpdate("""
                    INSERT INTO app_user (
                        user_id, created_at, last_seen_at
                    ) VALUES (
                        'handoff-upgrade-user',
                        '2026-07-30T07:00:00Z',
                        '2026-07-30T07:30:00Z'
                    )
                    """);
            statement.executeUpdate("""
                    INSERT INTO expedition_progress (
                        user_id,
                        expedition_id,
                        current_node_id,
                        progress_energy,
                        required_energy,
                        status,
                        unlocked_event_id,
                        version,
                        created_at,
                        updated_at
                    ) VALUES (
                        'handoff-upgrade-user',
                        'starter-expedition-v1',
                        'lumen-gate',
                        45,
                        45,
                        'COMPLETED',
                        'lumen-threshold-v1',
                        2,
                        '2026-07-30T07:00:00Z',
                        '2026-07-30T07:30:00Z'
                    )
                    """);
            statement.executeUpdate("""
                    INSERT INTO pilot_progress (
                        user_id, pilot_id, level, current_experience,
                        next_level_experience, version, created_at, updated_at
                    ) VALUES (
                        'handoff-upgrade-user',
                        'navigator-v1',
                        1,
                        60,
                        100,
                        1,
                        '2026-07-30T07:00:00Z',
                        '2026-07-30T07:30:00Z'
                    )
                    """);
            statement.executeUpdate("""
                    INSERT INTO pet_progress (
                        user_id, pet_id, level, bond, version,
                        created_at, updated_at
                    ) VALUES (
                        'handoff-upgrade-user',
                        'spark-v1',
                        1,
                        15,
                        1,
                        '2026-07-30T07:00:00Z',
                        '2026-07-30T07:30:00Z'
                    )
                    """);
            statement.executeUpdate("""
                    INSERT INTO processed_event_resolution (
                        user_id,
                        expedition_id,
                        event_id,
                        idempotency_key,
                        request_fingerprint,
                        content_version,
                        expedition_status,
                        expedition_version,
                        event_title,
                        resolution_status,
                        choice_id,
                        choice_title,
                        outcome_title,
                        outcome_summary,
                        pilot_id,
                        pilot_name,
                        pilot_level_after,
                        pilot_experience_gained,
                        pilot_experience_after,
                        pilot_next_level_experience,
                        pilot_version,
                        pet_id,
                        pet_name,
                        pet_level_after,
                        pet_bond_gained,
                        pet_bond_after,
                        pet_version,
                        server_time,
                        created_at
                    ) VALUES (
                        'handoff-upgrade-user',
                        'starter-expedition-v1',
                        'lumen-threshold-v1',
                        'legacy-event-result',
                        repeat('a', 64),
                        'starter-v2',
                        'COMPLETED',
                        2,
                        'Порог Люмена',
                        'RESOLVED',
                        'stabilize-threshold',
                        'Стабилизировать порог',
                        'Стабильный путь',
                        'Исторический результат уже был показан.',
                        'navigator-v1',
                        'Навигатор',
                        1,
                        20,
                        60,
                        100,
                        1,
                        'spark-v1',
                        'Искра',
                        1,
                        5,
                        15,
                        1,
                        '2026-07-30T07:30:00Z',
                        '2026-07-30T07:30:00Z'
                    )
                    """);
        }
    }

    private void seedPendingResult() throws Exception {
        try (Connection connection = connection();
             Statement statement = connection.createStatement()) {
            statement.executeUpdate("""
                    INSERT INTO processed_event_resolution (
                        user_id,
                        expedition_id,
                        event_id,
                        idempotency_key,
                        request_fingerprint,
                        content_version,
                        expedition_status,
                        expedition_version,
                        event_title,
                        resolution_status,
                        choice_id,
                        choice_title,
                        outcome_title,
                        outcome_summary,
                        pilot_id,
                        pilot_name,
                        pilot_level_after,
                        pilot_experience_gained,
                        pilot_experience_after,
                        pilot_next_level_experience,
                        pilot_version,
                        pet_id,
                        pet_name,
                        pet_level_after,
                        pet_bond_gained,
                        pet_bond_after,
                        pet_version,
                        handoff_required,
                        next_node_id,
                        next_node_name,
                        server_time,
                        created_at
                    ) VALUES (
                        'handoff-upgrade-user',
                        'starter-expedition-v1',
                        'signal-source-v1',
                        'new-event-result',
                        repeat('b', 64),
                        'starter-v2',
                        'IN_PROGRESS',
                        3,
                        'Источник сигнала',
                        'RESOLVED',
                        'analyze-signal',
                        'Проанализировать сигнал',
                        'Карта импульсов',
                        'Новый результат ждёт подтверждения.',
                        'navigator-v1',
                        'Навигатор',
                        1,
                        20,
                        80,
                        100,
                        2,
                        'spark-v1',
                        'Искра',
                        1,
                        5,
                        20,
                        2,
                        true,
                        'lumen-gate',
                        'Врата Люмена',
                        '2026-07-30T08:00:00Z',
                        '2026-07-30T08:00:00Z'
                    )
                    """);
            copyGameplayState(statement, "pending-v10-user");
            copyGameplayState(statement, "acknowledged-v10-user");
            statement.executeUpdate(copiedDurableResultSql(
                    "pending-v10-user",
                    "pending-v10-event-v1",
                    "pending-v10-result",
                    "NULL"
            ));
            statement.executeUpdate(copiedDurableResultSql(
                    "acknowledged-v10-user",
                    "acknowledged-v10-event-v1",
                    "acknowledged-v10-result",
                    "server_time + interval '2 minutes'"
            ));
        }
    }

    private void copyGameplayState(Statement statement, String userId)
            throws Exception {
        statement.executeUpdate("""
                INSERT INTO app_user (
                    user_id, created_at, last_seen_at,
                    has_successful_activity_sync
                )
                SELECT '%s', created_at, last_seen_at,
                       has_successful_activity_sync
                FROM app_user
                WHERE user_id = 'handoff-upgrade-user'
                """.formatted(userId));
        statement.executeUpdate("""
                INSERT INTO expedition_progress (
                    user_id, expedition_id, current_node_id,
                    progress_energy, required_energy, status,
                    unlocked_event_id, version, created_at, updated_at
                )
                SELECT '%s', expedition_id, current_node_id,
                       progress_energy, required_energy, status,
                       unlocked_event_id, version, created_at, updated_at
                FROM expedition_progress
                WHERE user_id = 'handoff-upgrade-user'
                """.formatted(userId));
        statement.executeUpdate("""
                INSERT INTO pilot_progress (
                    user_id, pilot_id, level, current_experience,
                    next_level_experience, version, created_at, updated_at
                )
                SELECT '%s', pilot_id, level, current_experience,
                       next_level_experience, version, created_at, updated_at
                FROM pilot_progress
                WHERE user_id = 'handoff-upgrade-user'
                """.formatted(userId));
        statement.executeUpdate("""
                INSERT INTO pet_progress (
                    user_id, pet_id, level, bond, version,
                    created_at, updated_at
                )
                SELECT '%s', pet_id, level, bond, version,
                       created_at, updated_at
                FROM pet_progress
                WHERE user_id = 'handoff-upgrade-user'
                """.formatted(userId));
    }

    private String copiedDurableResultSql(
            String userId,
            String eventId,
            String idempotencyKey,
            String acknowledgedAtExpression
    ) {
        return """
                INSERT INTO processed_event_resolution (
                    user_id,
                    expedition_id,
                    event_id,
                    idempotency_key,
                    request_fingerprint,
                    content_version,
                    expedition_status,
                    expedition_version,
                    event_title,
                    resolution_status,
                    choice_id,
                    choice_title,
                    outcome_title,
                    outcome_summary,
                    pilot_id,
                    pilot_name,
                    pilot_level_after,
                    pilot_experience_gained,
                    pilot_experience_after,
                    pilot_next_level_experience,
                    pilot_version,
                    pet_id,
                    pet_name,
                    pet_level_after,
                    pet_bond_gained,
                    pet_bond_after,
                    pet_version,
                    handoff_required,
                    next_node_id,
                    next_node_name,
                    acknowledged_at,
                    server_time,
                    created_at
                )
                SELECT
                    '%s',
                    expedition_id,
                    '%s',
                    '%s',
                    request_fingerprint,
                    content_version,
                    expedition_status,
                    expedition_version,
                    event_title,
                    resolution_status,
                    choice_id,
                    choice_title,
                    outcome_title,
                    outcome_summary,
                    pilot_id,
                    pilot_name,
                    pilot_level_after,
                    pilot_experience_gained,
                    pilot_experience_after,
                    pilot_next_level_experience,
                    pilot_version,
                    pet_id,
                    pet_name,
                    pet_level_after,
                    pet_bond_gained,
                    pet_bond_after,
                    pet_version,
                    true,
                    next_node_id,
                    next_node_name,
                    %s,
                    server_time + interval '1 minute',
                    created_at + interval '1 minute'
                FROM processed_event_resolution
                WHERE user_id = 'handoff-upgrade-user'
                  AND event_id = 'signal-source-v1'
                """.formatted(
                userId,
                eventId,
                idempotencyKey,
                acknowledgedAtExpression
        );
    }

    private Connection connection() throws Exception {
        return DriverManager.getConnection(
                POSTGRES.getJdbcUrl(),
                POSTGRES.getUsername(),
                POSTGRES.getPassword()
        );
    }

    private long scalarLong(Statement statement, String sql) throws Exception {
        try (ResultSet result = statement.executeQuery(sql)) {
            result.next();
            return result.getLong(1);
        }
    }
}
