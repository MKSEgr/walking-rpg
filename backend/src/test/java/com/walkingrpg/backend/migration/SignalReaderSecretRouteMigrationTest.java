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
class SignalReaderSecretRouteMigrationTest {

    @Container
    static final PostgreSQLContainer POSTGRES = PostgresTestContainer.create();

    @Test
    void shouldStageV14WithoutReplacingV13OrChangingSecretRouteJourney()
            throws Exception {
        Flyway.configure()
                .dataSource(
                        POSTGRES.getJdbcUrl(),
                        POSTGRES.getUsername(),
                        POSTGRES.getPassword()
                )
                .target(MigrationVersion.fromVersion("29"))
                .load()
                .migrate();
        seedV29State();

        Flyway flyway = Flyway.configure()
                .dataSource(
                        POSTGRES.getJdbcUrl(),
                        POSTGRES.getUsername(),
                        POSTGRES.getPassword()
                )
                .load();
        flyway.migrate();

        assertEquals("30", flyway.info().current().getVersion().getVersion());
        try (Connection connection = connection();
             Statement statement = connection.createStatement()) {
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM content_release
                    WHERE content_version = 'chapter-1-v14'
                      AND NOT is_active
                      AND activated_at IS NULL
                      AND content_json ->> 'nodeCount' = '27'
                      AND content_json ->> 'topology' =
                          'signal-reader-secret-route-v1'
                    """));
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM content_release
                    WHERE content_version = 'chapter-1-v13'
                      AND is_active
                    """));
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM roadmap_user_state
                    WHERE user_id = 'signal-secret-migration-user'
                      AND state_json -> 'unlockedSkills' ? 'signal-reader'
                      AND state_json ->> 'seasonXp' = '360'
                      AND version = 9
                    """));
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM pilot_progress
                    WHERE user_id = 'signal-secret-migration-user'
                      AND pilot_id = 'navigator-v1'
                      AND current_experience = 380
                      AND version = 6
                    """));
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM pet_progress
                    WHERE user_id = 'signal-secret-migration-user'
                      AND pet_id = 'spark-v1'
                      AND bond = 170
                      AND version = 7
                    """));
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM expedition_progress
                    WHERE user_id = 'signal-secret-migration-user'
                      AND current_node_id = 'constellation-sanctuary'
                      AND status = 'EVENT_READY'
                      AND unlocked_event_id = 'constellation-sanctuary-v1'
                      AND version = 51
                    """));
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM content_release
                    WHERE is_active
                    """));
        }
    }

    private void seedV29State() throws Exception {
        try (Connection connection = connection();
             Statement statement = connection.createStatement()) {
            statement.executeUpdate("""
                    INSERT INTO app_user (user_id, created_at, last_seen_at)
                    VALUES ('signal-secret-migration-user', now(), now())
                    """);
            statement.executeUpdate("""
                    INSERT INTO roadmap_user_state (
                        user_id, state_json, version, created_at, updated_at
                    ) VALUES (
                        'signal-secret-migration-user',
                        '{"seasonXp":360,"unlockedSkills":["signal-reader"]}'::jsonb,
                        9, now(), now()
                    )
                    """);
            statement.executeUpdate("""
                    INSERT INTO pilot_progress (
                        user_id, pilot_id, level, current_experience,
                        next_level_experience, version, created_at, updated_at
                    ) VALUES (
                        'signal-secret-migration-user', 'navigator-v1', 4, 380,
                        640, 6, now(), now()
                    )
                    """);
            statement.executeUpdate("""
                    INSERT INTO pet_progress (
                        user_id, pet_id, level, bond,
                        version, created_at, updated_at
                    ) VALUES (
                        'signal-secret-migration-user', 'spark-v1', 3, 170,
                        7, now(), now()
                    )
                    """);
            statement.executeUpdate("""
                    INSERT INTO expedition_progress (
                        user_id, expedition_id, current_node_id,
                        progress_energy, required_energy, status,
                        unlocked_event_id, version, created_at, updated_at
                    ) VALUES (
                        'signal-secret-migration-user',
                        'starter-expedition-v1', 'constellation-sanctuary',
                        80, 80, 'EVENT_READY', 'constellation-sanctuary-v1',
                        51, now(), now()
                    )
                    """);
            statement.executeUpdate(
                    "UPDATE content_release SET is_active = false WHERE is_active"
            );
            statement.executeUpdate("""
                    UPDATE content_release
                    SET is_active = true,
                        activated_at = COALESCE(activated_at, now())
                    WHERE content_version = 'chapter-1-v13'
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

    private int scalar(Statement statement, String sql) throws Exception {
        try (ResultSet result = statement.executeQuery(sql)) {
            result.next();
            return result.getInt(1);
        }
    }
}
