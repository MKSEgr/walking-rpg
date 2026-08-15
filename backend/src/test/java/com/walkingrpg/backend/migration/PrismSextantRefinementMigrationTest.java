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
class PrismSextantRefinementMigrationTest {

    @Container
    static final PostgreSQLContainer POSTGRES = PostgresTestContainer.create();

    @Test
    void shouldPreserveOwnedItemsAndEnforcePrismRefinement() throws Exception {
        Flyway.configure()
                .dataSource(
                        POSTGRES.getJdbcUrl(),
                        POSTGRES.getUsername(),
                        POSTGRES.getPassword()
                )
                .target(MigrationVersion.fromVersion("20"))
                .load()
                .migrate();
        seedV20Items();

        Flyway flyway = Flyway.configure()
                .dataSource(
                        POSTGRES.getJdbcUrl(),
                        POSTGRES.getUsername(),
                        POSTGRES.getPassword()
                )
                .load();
        flyway.migrate();

        assertEquals("22", flyway.info().current().getVersion().getVersion());
        try (Connection connection = connection();
             Statement statement = connection.createStatement()) {
            assertEquals("UNCOMMON", scalarString(statement, """
                    SELECT rarity
                    FROM unique_inventory_item
                    WHERE item_id = 'prism-sextant'
                    """));
            assertEquals("COMMON", scalarString(statement, """
                    SELECT rarity
                    FROM unique_inventory_item
                    WHERE item_id = 'resonance-compass'
                    """));
            assertEquals(2, scalar(statement, """
                    SELECT count(*)
                    FROM information_schema.tables
                    WHERE table_schema = 'public'
                      AND table_name IN (
                          'processed_item_upgrade_command',
                          'processed_item_upgrade_ingredient'
                      )
                    """));

            assertThrows(SQLException.class, () -> statement.executeUpdate("""
                    UPDATE unique_inventory_item
                    SET version = 2
                    WHERE item_id = 'prism-sextant'
                    """));
            statement.executeUpdate("""
                    UPDATE unique_inventory_item
                    SET version = 2,
                        rarity = 'RARE',
                        upgraded_at = now()
                    WHERE item_id = 'prism-sextant'
                    """);
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM unique_inventory_item
                    WHERE item_id = 'prism-sextant'
                      AND version = 2
                      AND rarity = 'RARE'
                      AND upgraded_at IS NOT NULL
                    """));
            assertThrows(SQLException.class, () -> statement.executeUpdate("""
                    UPDATE unique_inventory_item
                    SET version = 3
                    WHERE item_id = 'prism-sextant'
                    """));

            statement.executeUpdate("""
                    INSERT INTO processed_item_upgrade_command (
                        user_id, upgrade_id, idempotency_key,
                        request_fingerprint, content_version, upgrade_version,
                        upgrade_name, item_instance_id, item_id, item_name,
                        item_description, previous_level, result_level,
                        result_rarity, upgraded_at, server_time, created_at
                    ) VALUES (
                        'refinement-user', 'prism-sextant-calibration-v1',
                        'migration-upgrade', repeat('a', 64),
                        'item-upgrade-v1', '1', 'Калибровка',
                        '70000000-0000-0000-0000-000000000001',
                        'prism-sextant', 'Призматический секстант',
                        'Migration test item.', 1, 2, 'RARE', now(), now(), now()
                    )
                    """);
            statement.executeUpdate("""
                    INSERT INTO processed_item_upgrade_ingredient (
                        user_id, upgrade_id, idempotency_key, item_id, item_name,
                        quantity_consumed, quantity_after, inventory_version
                    ) VALUES (
                        'refinement-user', 'prism-sextant-calibration-v1',
                        'migration-upgrade', 'echo-thread', 'Нить эха', 2, 0, 2
                    )
                    """);
            statement.executeUpdate(
                    "DELETE FROM app_user WHERE user_id = 'refinement-user'"
            );
            assertEquals(0, scalar(statement, """
                    SELECT count(*) FROM processed_item_upgrade_command
                    """));
            assertEquals(0, scalar(statement, """
                    SELECT count(*) FROM processed_item_upgrade_ingredient
                    """));
        }
    }

    private void seedV20Items() throws Exception {
        try (Connection connection = connection();
             Statement statement = connection.createStatement()) {
            statement.executeUpdate("""
                    INSERT INTO app_user (user_id, created_at, last_seen_at)
                    VALUES ('refinement-user', now(), now())
                    """);
            statement.executeUpdate("""
                    INSERT INTO unique_inventory_item (
                        item_instance_id, user_id, item_id, recipe_id,
                        recipe_version, version, crafted_at
                    ) VALUES (
                        '70000000-0000-0000-0000-000000000001',
                        'refinement-user', 'prism-sextant',
                        'prism-sextant-v1', '1', 1, now()
                    ), (
                        '70000000-0000-0000-0000-000000000002',
                        'refinement-user', 'resonance-compass',
                        'resonance-compass-v1', '1', 1, now()
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

    private long scalar(Statement statement, String query) throws Exception {
        try (ResultSet result = statement.executeQuery(query)) {
            result.next();
            return result.getLong(1);
        }
    }

    private String scalarString(Statement statement, String query)
            throws Exception {
        try (ResultSet result = statement.executeQuery(query)) {
            result.next();
            return result.getString(1);
        }
    }
}
