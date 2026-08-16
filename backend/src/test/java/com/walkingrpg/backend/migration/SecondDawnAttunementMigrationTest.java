package com.walkingrpg.backend.migration;

import com.walkingrpg.backend.testsupport.PostgresTestContainer;
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
import static org.junit.jupiter.api.Assertions.assertThrows;

@Testcontainers
class SecondDawnAttunementMigrationTest {

    @Container
    static final PostgreSQLContainer POSTGRES = PostgresTestContainer.create();

    @Test
    void shouldStageV8AndAllowEpicAttunementWithoutReplacingV7()
            throws Exception {
        Flyway.configure()
                .dataSource(
                        POSTGRES.getJdbcUrl(),
                        POSTGRES.getUsername(),
                        POSTGRES.getPassword()
                )
                .target(MigrationVersion.fromVersion("23"))
                .load()
                .migrate();
        seedV23State();

        Flyway flyway = Flyway.configure()
                .dataSource(
                        POSTGRES.getJdbcUrl(),
                        POSTGRES.getUsername(),
                        POSTGRES.getPassword()
                )
                .load();
        flyway.migrate();

        assertEquals("28", flyway.info().current().getVersion().getVersion());
        try (Connection connection = connection();
             Statement statement = connection.createStatement()) {
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM unique_inventory_item
                    WHERE user_id = 'attunement-migration-user'
                      AND version = 2
                      AND rarity = 'RARE'
                    """));
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM processed_item_upgrade_command
                    WHERE upgrade_id = 'prism-sextant-calibration-v1'
                      AND result_rarity = 'RARE'
                    """));
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM content_release
                    WHERE content_version = 'chapter-1-v8'
                      AND NOT is_active
                      AND activated_at IS NULL
                      AND content_json ->> 'nodeCount' = '24'
                      AND content_json ->> 'topology' =
                          'second-dawn-attunement-v1'
                    """));
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM content_release
                    WHERE content_version = 'chapter-1-v7'
                      AND is_active
                    """));

            assertThrows(SQLException.class, () -> statement.executeUpdate("""
                    UPDATE unique_inventory_item
                    SET version = 3,
                        rarity = 'RARE',
                        upgraded_at = now()
                    WHERE user_id = 'attunement-migration-user'
                    """));
            statement.executeUpdate("""
                    UPDATE unique_inventory_item
                    SET version = 3,
                        rarity = 'EPIC',
                        upgraded_at = now()
                    WHERE user_id = 'attunement-migration-user'
                    """);
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM unique_inventory_item
                    WHERE user_id = 'attunement-migration-user'
                      AND version = 3
                      AND rarity = 'EPIC'
                    """));

            statement.executeUpdate("""
                    INSERT INTO processed_item_upgrade_command (
                        user_id, upgrade_id, idempotency_key,
                        request_fingerprint, content_version, upgrade_version,
                        upgrade_name, item_instance_id, item_id, item_name,
                        item_description, previous_level, result_level,
                        result_rarity, upgraded_at, server_time, created_at
                    ) VALUES (
                        'attunement-migration-user',
                        'prism-sextant-second-dawn-attunement-v1',
                        'attunement-migration', repeat('b', 64),
                        'item-upgrade-v2', '1', 'Настройка второго рассвета',
                        '70000000-0000-0000-0000-000000000001',
                        'prism-sextant', 'Призматический секстант',
                        'Migration test item.', 2, 3, 'EPIC', now(), now(), now()
                    )
                    """);
            assertEquals(2, scalar(statement, """
                    SELECT count(*) FROM processed_item_upgrade_command
                    """));
            statement.executeUpdate("""
                    DELETE FROM app_user
                    WHERE user_id = 'attunement-migration-user'
                    """);
            assertEquals(0, scalar(statement, """
                    SELECT count(*) FROM unique_inventory_item
                    """));
            assertEquals(0, scalar(statement, """
                    SELECT count(*) FROM processed_item_upgrade_command
                    """));
        }
    }

    private void seedV23State() throws Exception {
        try (Connection connection = connection();
             Statement statement = connection.createStatement()) {
            statement.executeUpdate("""
                    INSERT INTO app_user (user_id, created_at, last_seen_at)
                    VALUES ('attunement-migration-user', now(), now())
                    """);
            statement.executeUpdate("""
                    INSERT INTO unique_inventory_item (
                        item_instance_id, user_id, item_id, recipe_id,
                        recipe_version, version, rarity, crafted_at, upgraded_at
                    ) VALUES (
                        '70000000-0000-0000-0000-000000000001',
                        'attunement-migration-user', 'prism-sextant',
                        'prism-sextant-v1', '1', 2, 'RARE', now(), now()
                    )
                    """);
            statement.executeUpdate("""
                    INSERT INTO processed_item_upgrade_command (
                        user_id, upgrade_id, idempotency_key,
                        request_fingerprint, content_version, upgrade_version,
                        upgrade_name, item_instance_id, item_id, item_name,
                        item_description, previous_level, result_level,
                        result_rarity, upgraded_at, server_time, created_at
                    ) VALUES (
                        'attunement-migration-user',
                        'prism-sextant-calibration-v1', 'calibration-migration',
                        repeat('a', 64), 'item-upgrade-v1', '1', 'Калибровка',
                        '70000000-0000-0000-0000-000000000001',
                        'prism-sextant', 'Призматический секстант',
                        'Migration test item.', 1, 2, 'RARE', now(), now(), now()
                    )
                    """);
            statement.executeUpdate(
                    "UPDATE content_release SET is_active = false WHERE is_active"
            );
            statement.executeUpdate("""
                    UPDATE content_release
                    SET is_active = true,
                        activated_at = COALESCE(activated_at, now())
                    WHERE content_version = 'chapter-1-v7'
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

    private long scalar(Statement statement, String query) throws Exception {
        try (ResultSet result = statement.executeQuery(query)) {
            result.next();
            return result.getLong(1);
        }
    }
}
