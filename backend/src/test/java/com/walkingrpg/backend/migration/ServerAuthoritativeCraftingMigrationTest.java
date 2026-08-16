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
class ServerAuthoritativeCraftingMigrationTest {

    @Container
    static final PostgreSQLContainer POSTGRES =
            PostgresTestContainer.create();

    @Test
    void shouldUpgradeV12PreserveRewardsAndAllowAuditedConsumption()
            throws Exception {
        Flyway.configure()
                .dataSource(
                        POSTGRES.getJdbcUrl(),
                        POSTGRES.getUsername(),
                        POSTGRES.getPassword()
                )
                .target(MigrationVersion.fromVersion("12"))
                .load()
                .migrate();
        seedV12Inventory();
        try (Connection connection = connection(); Statement statement = connection.createStatement()) {
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM pg_constraint
                    WHERE conrelid = 'inventory_ledger'::regclass
                      AND conname = 'inventory_ledger_quantity_delta_check'
                    """));
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM pg_constraint
                    WHERE conrelid = 'inventory_ledger'::regclass
                      AND conname = 'inventory_ledger_check'
                    """));
        }

        Flyway flyway = Flyway.configure()
                .dataSource(
                        POSTGRES.getJdbcUrl(),
                        POSTGRES.getUsername(),
                        POSTGRES.getPassword()
                )
                .load();
        flyway.migrate();

        assertEquals("31", flyway.info().current().getVersion().getVersion());
        try (Connection connection = connection(); Statement statement = connection.createStatement()) {
            assertEquals(3, scalar(statement, """
                    SELECT quantity
                    FROM inventory_stack
                    WHERE user_id = 'upgrade-craft-user'
                      AND item_id = 'lumen-shard'
                    """));
            assertEquals(1, scalar(statement, "SELECT count(*) FROM inventory_ledger"));
            assertEquals(0, scalar(statement, "SELECT count(*) FROM unique_inventory_item"));
            assertEquals(0, scalar(statement, "SELECT count(*) FROM processed_crafting_command"));
            assertEquals(0, scalar(statement, """
                    SELECT count(*)
                    FROM pg_constraint
                    WHERE conrelid = 'inventory_ledger'::regclass
                      AND conname IN (
                          'inventory_ledger_quantity_delta_check',
                          'inventory_ledger_check'
                      )
                    """));
            assertEquals(2, scalar(statement, """
                    SELECT count(*)
                    FROM pg_constraint
                    WHERE conrelid = 'inventory_ledger'::regclass
                      AND conname IN (
                          'ck_inventory_ledger_quantity_delta_non_zero',
                          'ck_inventory_ledger_quantity_after_non_negative'
                      )
                    """));

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
                        gen_random_uuid(),
                        'upgrade-craft-user',
                        'lumen-shard',
                        -2,
                        1,
                        2,
                        'CRAFTING_INGREDIENT_CONSUMED',
                        'CRAFTING_COMMAND',
                        'migration-negative',
                        now()
                    )
                    """);
            assertEquals(-1, scalar(statement, "SELECT sum(quantity_delta) FROM inventory_ledger"));

            assertThrows(SQLException.class, () -> statement.executeUpdate("""
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
                        gen_random_uuid(),
                        'upgrade-craft-user',
                        'lumen-shard',
                        0,
                        1,
                        3,
                        'INVALID',
                        'TEST',
                        'zero-delta',
                        now()
                    )
                    """));
        }
    }

    private void seedV12Inventory() throws Exception {
        try (Connection connection = connection(); Statement statement = connection.createStatement()) {
            statement.executeUpdate("""
                    INSERT INTO app_user (user_id, created_at, last_seen_at)
                    VALUES ('upgrade-craft-user', now(), now())
                    """);
            statement.executeUpdate("""
                    INSERT INTO inventory_stack (
                        user_id, item_id, quantity, version, created_at, updated_at
                    ) VALUES (
                        'upgrade-craft-user', 'lumen-shard', 3, 1, now(), now()
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
                        gen_random_uuid(),
                        'upgrade-craft-user',
                        'lumen-shard',
                        1,
                        3,
                        1,
                        'EVENT_MATERIAL_REWARD',
                        'EVENT_RESOLUTION',
                        'historical-reward',
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

    private long scalar(Statement statement, String query) throws Exception {
        try (ResultSet result = statement.executeQuery(query)) {
            result.next();
            return result.getLong(1);
        }
    }
}
