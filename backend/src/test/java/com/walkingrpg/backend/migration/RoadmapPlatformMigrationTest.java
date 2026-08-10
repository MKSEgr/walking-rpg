package com.walkingrpg.backend.migration;

import com.walkingrpg.backend.testsupport.PostgresTestContainer;
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
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;

@Testcontainers
class RoadmapPlatformMigrationTest {

    @Container
    static final PostgreSQLContainer POSTGRES =
            PostgresTestContainer.create();

    @Test
    void shouldUpgradeCompletedSecondNodeWithoutChangingHistoricalReward() throws Exception {
        migrateTo("5");
        seedCompletedSecondNode();

        migrateAll();

        try (Connection connection = connection(); Statement statement = connection.createStatement()) {
            try (ResultSet result = statement.executeQuery("""
                    SELECT current_node_id,
                           progress_energy,
                           required_energy,
                           status,
                           unlocked_event_id,
                           version
                    FROM expedition_progress
                    WHERE user_id = 'roadmap-upgrade-user'
                    """)) {
                result.next();
                assertEquals("ash-orbit", result.getString("current_node_id"));
                assertEquals(0, result.getLong("progress_energy"));
                assertEquals(55, result.getLong("required_energy"));
                assertEquals("IN_PROGRESS", result.getString("status"));
                assertNull(result.getString("unlocked_event_id"));
                assertEquals(5, result.getLong("version"));
            }

            try (ResultSet result = statement.executeQuery("""
                    SELECT content_version,
                           expedition_status,
                           expedition_version,
                           choice_id,
                           material_item_id,
                           material_quantity_gained,
                           material_quantity_after,
                           material_version
                    FROM processed_event_resolution
                    WHERE user_id = 'roadmap-upgrade-user'
                      AND event_id = 'echo-vault-v1'
                    """)) {
                result.next();
                assertEquals("starter-v2", result.getString("content_version"));
                assertEquals("COMPLETED", result.getString("expedition_status"));
                assertEquals(4, result.getLong("expedition_version"));
                assertEquals("stabilize-core", result.getString("choice_id"));
                assertEquals("lumen-shard", result.getString("material_item_id"));
                assertEquals(2, result.getLong("material_quantity_gained"));
                assertEquals(2, result.getLong("material_quantity_after"));
                assertEquals(1, result.getLong("material_version"));
            }

            assertEquals(2, scalarLong(statement, """
                    SELECT quantity
                    FROM inventory_stack
                    WHERE user_id = 'roadmap-upgrade-user'
                      AND item_id = 'lumen-shard'
                    """));
            assertEquals(1, scalarLong(statement, """
                    SELECT count(*)
                    FROM inventory_ledger
                    WHERE user_id = 'roadmap-upgrade-user'
                    """));
            assertEquals("roadmap-v1", scalarString(statement, """
                    SELECT config_version
                    FROM remote_config_snapshot
                    WHERE is_active
                    """));
            assertEquals("chapter-1-v1", scalarString(statement, """
                    SELECT content_version
                    FROM content_release
                    WHERE is_active
                    """));
            assertNotNull(scalarString(statement,
                    "SELECT to_regclass('public.roadmap_user_state')::text"));
            assertNotNull(scalarString(statement,
                    "SELECT to_regclass('public.activity_risk_assessment')::text"));
            assertNotNull(scalarString(statement,
                    "SELECT to_regclass('public.account_deletion_receipt')::text"));
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

    private void seedCompletedSecondNode() throws Exception {
        try (Connection connection = connection(); Statement statement = connection.createStatement()) {
            statement.executeUpdate("""
                    INSERT INTO app_user (user_id, created_at, last_seen_at)
                    VALUES ('roadmap-upgrade-user', now(), now())
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
                        'roadmap-upgrade-user',
                        'starter-expedition-v1',
                        'lumen-gate',
                        45,
                        45,
                        'COMPLETED',
                        'echo-vault-v1',
                        4,
                        now(),
                        now()
                    )
                    """);
            statement.executeUpdate("""
                    INSERT INTO pilot_progress (
                        user_id, pilot_id, level, current_experience,
                        next_level_experience, version, created_at, updated_at
                    ) VALUES (
                        'roadmap-upgrade-user', 'navigator-v1', 1, 90,
                        100, 2, now(), now()
                    )
                    """);
            statement.executeUpdate("""
                    INSERT INTO pet_progress (
                        user_id, pet_id, level, bond, version, created_at, updated_at
                    ) VALUES (
                        'roadmap-upgrade-user', 'spark-v1', 1, 23, 2, now(), now()
                    )
                    """);
            statement.executeUpdate("""
                    INSERT INTO inventory_stack (
                        user_id, item_id, quantity, version, created_at, updated_at
                    ) VALUES (
                        'roadmap-upgrade-user', 'lumen-shard', 2, 1, now(), now()
                    )
                    """);
            statement.executeUpdate("""
                    INSERT INTO inventory_ledger (
                        ledger_entry_id,
                        user_id,
                        item_id,
                        quantity_delta,
                        quantity_after,
                        inventory_version,
                        reason_code,
                        source_type,
                        source_key,
                        created_at
                    ) VALUES (
                        '11111111-1111-1111-1111-111111111111',
                        'roadmap-upgrade-user',
                        'lumen-shard',
                        2,
                        2,
                        1,
                        'EVENT_REWARD',
                        'EVENT_RESOLUTION',
                        'starter-expedition-v1:echo-vault-v1',
                        now()
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
                        created_at,
                        material_item_id,
                        material_item_name,
                        material_item_description,
                        material_quantity_gained,
                        material_quantity_after,
                        material_version
                    ) VALUES (
                        'roadmap-upgrade-user',
                        'starter-expedition-v1',
                        'echo-vault-v1',
                        'historical-second-event',
                        repeat('b', 64),
                        'starter-v2',
                        'COMPLETED',
                        4,
                        'Хранилище эха',
                        'RESOLVED',
                        'stabilize-core',
                        'Стабилизировать ядро',
                        'Стабильный резонанс',
                        'Исторический результат второго события.',
                        'navigator-v1',
                        'Навигатор',
                        1,
                        30,
                        90,
                        100,
                        2,
                        'spark-v1',
                        'Искра',
                        1,
                        8,
                        23,
                        2,
                        now(),
                        now(),
                        'lumen-shard',
                        'Люминовый осколок',
                        'Стабильный фрагмент резонансного ядра.',
                        2,
                        2,
                        1
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

    private String scalarString(Statement statement, String sql) throws Exception {
        try (ResultSet result = statement.executeQuery(sql)) {
            result.next();
            return result.getString(1);
        }
    }
}
