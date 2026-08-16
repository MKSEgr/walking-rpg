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

@Testcontainers
class UnchartedVergeMigrationTest {

    @Container
    static final PostgreSQLContainer POSTGRES = PostgresTestContainer.create();

    @Test
    void shouldStageV9WithoutReplacingActiveV8OrChangingEpicItems()
            throws Exception {
        Flyway.configure()
                .dataSource(
                        POSTGRES.getJdbcUrl(),
                        POSTGRES.getUsername(),
                        POSTGRES.getPassword()
                )
                .target(MigrationVersion.fromVersion("24"))
                .load()
                .migrate();
        seedV24State();

        Flyway flyway = Flyway.configure()
                .dataSource(
                        POSTGRES.getJdbcUrl(),
                        POSTGRES.getUsername(),
                        POSTGRES.getPassword()
                )
                .load();
        flyway.migrate();

        assertEquals("33", flyway.info().current().getVersion().getVersion());
        try (Connection connection = connection();
             Statement statement = connection.createStatement()) {
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM content_release
                    WHERE content_version = 'chapter-1-v9'
                      AND NOT is_active
                      AND activated_at IS NULL
                      AND content_json ->> 'nodeCount' = '25'
                      AND content_json ->> 'topology' =
                          'epic-sextant-uncharted-verge-v1'
                    """));
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM content_release
                    WHERE content_version = 'chapter-1-v8'
                      AND is_active
                    """));
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM unique_inventory_item
                    WHERE user_id = 'uncharted-migration-user'
                      AND version = 3
                      AND rarity = 'EPIC'
                      AND upgraded_at IS NOT NULL
                    """));
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM processed_item_upgrade_command
                    WHERE user_id = 'uncharted-migration-user'
                      AND upgrade_id =
                          'prism-sextant-second-dawn-attunement-v1'
                      AND result_level = 3
                      AND result_rarity = 'EPIC'
                    """));
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM content_release
                    WHERE is_active
                    """));
        }
    }

    private void seedV24State() throws Exception {
        try (Connection connection = connection();
             Statement statement = connection.createStatement()) {
            statement.executeUpdate("""
                    INSERT INTO app_user (user_id, created_at, last_seen_at)
                    VALUES ('uncharted-migration-user', now(), now())
                    """);
            statement.executeUpdate("""
                    INSERT INTO unique_inventory_item (
                        item_instance_id, user_id, item_id, recipe_id,
                        recipe_version, version, rarity, crafted_at, upgraded_at
                    ) VALUES (
                        '80000000-0000-0000-0000-000000000001',
                        'uncharted-migration-user', 'prism-sextant',
                        'prism-sextant-v1', '1', 3, 'EPIC', now(), now()
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
                        'uncharted-migration-user',
                        'prism-sextant-second-dawn-attunement-v1',
                        'uncharted-attunement', repeat('c', 64),
                        'item-upgrade-v2', '1', 'Настройка второго рассвета',
                        '80000000-0000-0000-0000-000000000001',
                        'prism-sextant', 'Призматический секстант',
                        'Migration test item.', 2, 3, 'EPIC', now(), now(), now()
                    )
                    """);
            statement.executeUpdate(
                    "UPDATE content_release SET is_active = false WHERE is_active"
            );
            statement.executeUpdate("""
                    UPDATE content_release
                    SET is_active = true,
                        activated_at = COALESCE(activated_at, now())
                    WHERE content_version = 'chapter-1-v8'
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
