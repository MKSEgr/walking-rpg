package com.walkingrpg.backend.migration;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;

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

        migrateAll();

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
            assertEquals(2, scalarLong(statement, """
                    SELECT count(*)
                    FROM processed_event_resolution
                    WHERE user_id = 'handoff-upgrade-user'
                      AND NOT handoff_required
                      AND acknowledged_at IS NOT NULL
                    """));

            assertThrows(SQLException.class, () -> statement.executeUpdate("""
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
                    )
                    SELECT
                        user_id,
                        expedition_id,
                        'parallel-event-v1',
                        'parallel-event-result',
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
                        server_time + interval '1 minute',
                        created_at + interval '1 minute'
                    FROM processed_event_resolution
                    WHERE user_id = 'handoff-upgrade-user'
                      AND event_id = 'signal-source-v1'
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
