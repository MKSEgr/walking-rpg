package com.walkingrpg.backend.migration;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.Statement;

import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.MigrationVersion;
import org.junit.jupiter.api.Test;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

@Testcontainers
class SecondNodeInventoryMigrationTest {

    @Container
    static final PostgreSQLContainer POSTGRES =
            new PostgreSQLContainer("postgres:17-alpine");

    @Test
    void shouldMoveCompletedStarterV1UserToSecondNodeWithoutReissuingReward()
            throws Exception {
        Flyway.configure()
                .dataSource(
                        POSTGRES.getJdbcUrl(),
                        POSTGRES.getUsername(),
                        POSTGRES.getPassword()
                )
                .target(MigrationVersion.fromVersion("4"))
                .load()
                .migrate();
        seedCompletedV1State();

        Flyway.configure()
                .dataSource(
                        POSTGRES.getJdbcUrl(),
                        POSTGRES.getUsername(),
                        POSTGRES.getPassword()
                )
                .load()
                .migrate();

        try (Connection connection = connection(); Statement statement = connection.createStatement()) {
            try (ResultSet result = statement.executeQuery("""
                    SELECT current_node_id,
                           progress_energy,
                           required_energy,
                           status,
                           unlocked_event_id,
                           version
                    FROM expedition_progress
                    WHERE user_id = 'upgrade-user'
                    """)) {
                result.next();
                assertEquals("lumen-gate", result.getString("current_node_id"));
                assertEquals(0, result.getLong("progress_energy"));
                assertEquals(45, result.getLong("required_energy"));
                assertEquals("IN_PROGRESS", result.getString("status"));
                assertNull(result.getString("unlocked_event_id"));
                assertEquals(3, result.getLong("version"));
            }
            try (ResultSet result = statement.executeQuery("""
                    SELECT expedition_status,
                           material_item_id,
                           material_quantity_gained
                    FROM processed_event_resolution
                    WHERE user_id = 'upgrade-user'
                      AND event_id = 'signal-source-v1'
                    """)) {
                result.next();
                assertEquals("COMPLETED", result.getString("expedition_status"));
                assertNull(result.getString("material_item_id"));
                assertNull(result.getObject("material_quantity_gained"));
            }
            assertEquals(0, count(statement, "inventory_stack"));
            assertEquals(0, count(statement, "inventory_ledger"));
        }
    }

    private void seedCompletedV1State() throws Exception {
        try (Connection connection = connection(); Statement statement = connection.createStatement()) {
            statement.executeUpdate("""
                    INSERT INTO app_user (user_id, created_at, last_seen_at)
                    VALUES ('upgrade-user', now(), now())
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
                        'upgrade-user',
                        'starter-expedition-v1',
                        'outer-beacon',
                        30,
                        30,
                        'COMPLETED',
                        'signal-source-v1',
                        2,
                        now(),
                        now()
                    )
                    """);
            statement.executeUpdate("""
                    INSERT INTO pilot_progress (
                        user_id, pilot_id, level, current_experience,
                        next_level_experience, version, created_at, updated_at
                    ) VALUES (
                        'upgrade-user', 'navigator-v1', 1, 60, 100, 1, now(), now()
                    )
                    """);
            statement.executeUpdate("""
                    INSERT INTO pet_progress (
                        user_id, pet_id, level, bond, version, created_at, updated_at
                    ) VALUES (
                        'upgrade-user', 'spark-v1', 1, 15, 1, now(), now()
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
                        'upgrade-user',
                        'starter-expedition-v1',
                        'signal-source-v1',
                        'historical-event',
                        repeat('a', 64),
                        'starter-v1',
                        'COMPLETED',
                        2,
                        'Источник сигнала',
                        'RESOLVED',
                        'analyze-signal',
                        'Проанализировать сигнал',
                        'Карта импульсов',
                        'Исторический результат.',
                        'navigator-v1',
                        'Навигатор',
                        1,
                        40,
                        60,
                        100,
                        1,
                        'spark-v1',
                        'Искра',
                        1,
                        5,
                        15,
                        1,
                        now(),
                        now()
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

    private int count(Statement statement, String table) throws Exception {
        try (ResultSet result = statement.executeQuery("SELECT count(*) FROM " + table)) {
            result.next();
            return result.getInt(1);
        }
    }
}
