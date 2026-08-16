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
class CosmeticSlotStateMigrationTest {

    @Container
    static final PostgreSQLContainer POSTGRES =
            PostgresTestContainer.create();

    @Test
    void shouldBackfillKnownLegacySelectionIntoItsServerOwnedSlot()
            throws Exception {
        migrateTo("16");
        seedLegacyState();

        Flyway flyway = flyway();
        flyway.migrate();

        assertEquals("27", flyway.info().current().getVersion().getVersion());
        try (Connection connection = connection(); Statement statement = connection.createStatement()) {
            assertEquals(3, scalarLong(statement, """
                    SELECT count(*)
                    FROM platform_cosmetic_slot_state
                    """));
            assertEquals("PILOT:pilot-scarf", scalarString(statement, """
                    SELECT slot || ':' || cosmetic_id
                    FROM platform_cosmetic_slot_state
                    WHERE user_id = 'legacy-pilot-user'
                    """));
            assertEquals("PET:spark-halo", scalarString(statement, """
                    SELECT slot || ':' || cosmetic_id
                    FROM platform_cosmetic_slot_state
                    WHERE user_id = 'legacy-pet-user'
                    """));
            assertEquals("PROFILE:dawn-frame", scalarString(statement, """
                    SELECT slot || ':' || cosmetic_id
                    FROM platform_cosmetic_slot_state
                    WHERE user_id = 'legacy-profile-user'
                    """));
            assertEquals(0, scalarLong(statement, """
                    SELECT count(*)
                    FROM platform_cosmetic_slot_state
                    WHERE user_id = 'unknown-cosmetic-user'
                    """));

            assertThrows(SQLException.class, () -> statement.executeUpdate("""
                    INSERT INTO platform_cosmetic_slot_state (
                        user_id, slot, cosmetic_id, version,
                        equipped_at, updated_at
                    ) VALUES (
                        'legacy-pilot-user', 'UNKNOWN', 'future-cosmetic', 1,
                        now(), now()
                    )
                    """));
            assertThrows(SQLException.class, () -> statement.executeUpdate("""
                    INSERT INTO platform_cosmetic_slot_state (
                        user_id, slot, cosmetic_id, version,
                        equipped_at, updated_at
                    ) VALUES (
                        'legacy-pilot-user', 'PET', 'pilot-scarf', 1,
                        now(), now()
                    )
                    """));

            statement.executeUpdate("""
                    DELETE FROM app_user
                    WHERE user_id = 'legacy-pet-user'
                    """);
            assertEquals(0, scalarLong(statement, """
                    SELECT count(*)
                    FROM platform_cosmetic_slot_state
                    WHERE user_id = 'legacy-pet-user'
                    """));
        }
    }

    private void seedLegacyState() throws Exception {
        try (Connection connection = connection(); Statement statement = connection.createStatement()) {
            statement.executeUpdate("""
                    INSERT INTO app_user (user_id, created_at, last_seen_at)
                    VALUES
                        ('legacy-pilot-user', now(), now()),
                        ('legacy-pet-user', now(), now()),
                        ('legacy-profile-user', now(), now()),
                        ('unknown-cosmetic-user', now(), now())
                    """);
            statement.executeUpdate("""
                    INSERT INTO roadmap_user_state (
                        user_id, state_json, version, created_at, updated_at
                    ) VALUES
                        (
                            'legacy-pilot-user',
                            '{"activeCosmeticId":"pilot-scarf"}'::jsonb,
                            1, now(), now()
                        ),
                        (
                            'legacy-pet-user',
                            '{"activeCosmeticId":"spark-halo"}'::jsonb,
                            1, now(), now()
                        ),
                        (
                            'legacy-profile-user',
                            '{"activeCosmeticId":"dawn-frame"}'::jsonb,
                            1, now(), now()
                        ),
                        (
                            'unknown-cosmetic-user',
                            '{"activeCosmeticId":"future-cosmetic"}'::jsonb,
                            1, now(), now()
                        )
                    """);
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

    private Flyway flyway() {
        return Flyway.configure()
                .dataSource(
                        POSTGRES.getJdbcUrl(),
                        POSTGRES.getUsername(),
                        POSTGRES.getPassword()
                )
                .load();
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
