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
class SteadyStepFirstLightCausewayMigrationTest {

    @Container
    static final PostgreSQLContainer POSTGRES = PostgresTestContainer.create();

    @Test
    void shouldStageV17WithoutReplacingV16OrChangingDawnJourney()
            throws Exception {
        Flyway.configure()
                .dataSource(
                        POSTGRES.getJdbcUrl(),
                        POSTGRES.getUsername(),
                        POSTGRES.getPassword()
                )
                .target(MigrationVersion.fromVersion("32"))
                .load()
                .migrate();
        seedV32State();

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
                    WHERE content_version = 'chapter-1-v17'
                      AND NOT is_active
                      AND activated_at IS NULL
                      AND content_json ->> 'nodeCount' = '30'
                      AND content_json ->> 'topology' =
                          'steady-step-first-light-causeway-v1'
                    """));
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM content_release
                    WHERE content_version = 'chapter-1-v16'
                      AND is_active
                    """));
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM roadmap_user_state
                    WHERE user_id = 'steady-step-migration-user'
                      AND state_json -> 'unlockedSkills' ? 'steady-step'
                      AND state_json ->> 'seasonXp' = '0'
                      AND version = 12
                    """));
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM pilot_progress
                    WHERE user_id = 'steady-step-migration-user'
                      AND pilot_id = 'navigator-v1'
                      AND current_experience = 708
                      AND version = 9
                    """));
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM pet_progress
                    WHERE user_id = 'steady-step-migration-user'
                      AND pet_id = 'spark-v1'
                      AND bond = 404
                      AND version = 10
                    """));
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM expedition_progress
                    WHERE user_id = 'steady-step-migration-user'
                      AND current_node_id = 'dawn-meridian'
                      AND status = 'EVENT_READY'
                      AND unlocked_event_id = 'dawn-meridian-v1'
                      AND version = 56
                    """));
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM content_release
                    WHERE is_active
                    """));
        }
    }

    private void seedV32State() throws Exception {
        try (Connection connection = connection();
             Statement statement = connection.createStatement()) {
            statement.executeUpdate("""
                    INSERT INTO app_user (user_id, created_at, last_seen_at)
                    VALUES ('steady-step-migration-user', now(), now())
                    """);
            statement.executeUpdate("""
                    INSERT INTO roadmap_user_state (
                        user_id, state_json, version, created_at, updated_at
                    ) VALUES (
                        'steady-step-migration-user',
                        '{"seasonXp":0,"unlockedSkills":["steady-step"]}'::jsonb,
                        12, now(), now()
                    )
                    """);
            statement.executeUpdate("""
                    INSERT INTO pilot_progress (
                        user_id, pilot_id, level, current_experience,
                        next_level_experience, version, created_at, updated_at
                    ) VALUES (
                        'steady-step-migration-user', 'navigator-v1', 6,
                        708, 900, 9, now(), now()
                    )
                    """);
            statement.executeUpdate("""
                    INSERT INTO pet_progress (
                        user_id, pet_id, level, bond,
                        version, created_at, updated_at
                    ) VALUES (
                        'steady-step-migration-user', 'spark-v1', 5, 404,
                        10, now(), now()
                    )
                    """);
            statement.executeUpdate("""
                    INSERT INTO expedition_progress (
                        user_id, expedition_id, current_node_id,
                        progress_energy, required_energy, status,
                        unlocked_event_id, version, created_at, updated_at
                    ) VALUES (
                        'steady-step-migration-user',
                        'starter-expedition-v1', 'dawn-meridian',
                        100, 100, 'EVENT_READY',
                        'dawn-meridian-v1', 56, now(), now()
                    )
                    """);
            statement.executeUpdate(
                    "UPDATE content_release SET is_active = false WHERE is_active"
            );
            statement.executeUpdate("""
                    UPDATE content_release
                    SET is_active = true,
                        activated_at = COALESCE(activated_at, now())
                    WHERE content_version = 'chapter-1-v16'
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
