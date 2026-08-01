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
import static org.junit.jupiter.api.Assertions.assertThrows;

@Testcontainers
class EquipmentAndResonanceRouteMigrationTest {

    @Container
    static final PostgreSQLContainer POSTGRES =
            new PostgreSQLContainer("postgres:17-alpine");

    @Test
    void shouldUpgradeV13PreserveUniqueItemAndStageChapterV2()
            throws Exception {
        Flyway.configure()
                .dataSource(
                        POSTGRES.getJdbcUrl(),
                        POSTGRES.getUsername(),
                        POSTGRES.getPassword()
                )
                .target(MigrationVersion.fromVersion("13"))
                .load()
                .migrate();
        seedV13UniqueItem();

        Flyway flyway = Flyway.configure()
                .dataSource(
                        POSTGRES.getJdbcUrl(),
                        POSTGRES.getUsername(),
                        POSTGRES.getPassword()
                )
                .load();
        flyway.migrate();

        assertEquals("14", flyway.info().current().getVersion().getVersion());
        try (Connection connection = connection();
             Statement statement = connection.createStatement()) {
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM unique_inventory_item
                    WHERE user_id = 'equipment-upgrade-user'
                      AND item_id = 'resonance-compass'
                    """));
            assertEquals(0, scalar(statement,
                    "SELECT count(*) FROM equipment_slot_state"));
            assertEquals(0, scalar(statement,
                    "SELECT count(*) FROM processed_equipment_command"));
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM content_release
                    WHERE content_version = 'chapter-1-v2'
                      AND NOT is_active
                      AND content_json ->> 'nodeCount' = '19'
                    """));
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM content_release
                    WHERE content_version = 'chapter-1-v1'
                      AND is_active
                    """));
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM content_release
                    WHERE is_active
                    """));
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM pg_constraint
                    WHERE conrelid = 'equipment_slot_state'::regclass
                      AND conname = 'fk_equipment_slot_owned_item'
                    """));

            statement.executeUpdate("""
                    INSERT INTO equipment_slot_state (
                        user_id,
                        slot_id,
                        item_instance_id,
                        version,
                        equipped_at,
                        updated_at
                    )
                    SELECT user_id,
                           'NAVIGATION',
                           item_instance_id,
                           1,
                           now(),
                           now()
                    FROM unique_inventory_item
                    WHERE user_id = 'equipment-upgrade-user'
                    """);
            assertEquals(1, scalar(statement,
                    "SELECT count(*) FROM equipment_slot_state"));

            assertThrows(SQLException.class, () -> statement.executeUpdate("""
                    UPDATE equipment_slot_state
                    SET equipped_at = NULL
                    WHERE user_id = 'equipment-upgrade-user'
                    """));
            assertThrows(SQLException.class, () -> statement.executeUpdate("""
                    INSERT INTO processed_equipment_command (
                        user_id,
                        slot_id,
                        idempotency_key,
                        request_fingerprint,
                        content_version,
                        action,
                        changed,
                        slot_name,
                        slot_description,
                        equipment_version,
                        item_instance_id,
                        item_id,
                        item_name,
                        item_description,
                        equipped_at,
                        server_time,
                        created_at
                    ) VALUES (
                        'equipment-upgrade-user',
                        'NAVIGATION',
                        'partial-item-snapshot',
                        repeat('a', 64),
                        'equipment-v1',
                        'EQUIP',
                        true,
                        'Навигационный прибор',
                        'Описание слота',
                        1,
                        '11111111-2222-3333-4444-555555555555',
                        'resonance-compass',
                        NULL,
                        'Описание предмета',
                        now(),
                        now(),
                        now()
                    )
                    """));
        }
    }

    private void seedV13UniqueItem() throws Exception {
        try (Connection connection = connection();
             Statement statement = connection.createStatement()) {
            statement.executeUpdate("""
                    INSERT INTO app_user (user_id, created_at, last_seen_at)
                    VALUES ('equipment-upgrade-user', now(), now())
                    """);
            statement.executeUpdate("""
                    INSERT INTO unique_inventory_item (
                        item_instance_id,
                        user_id,
                        item_id,
                        recipe_id,
                        recipe_version,
                        version,
                        crafted_at
                    ) VALUES (
                        '11111111-2222-3333-4444-555555555555',
                        'equipment-upgrade-user',
                        'resonance-compass',
                        'resonance-compass-v1',
                        '1',
                        1,
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
