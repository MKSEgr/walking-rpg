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
class AdultPetFrontierRouteMigrationTest {

    @Container
    static final PostgreSQLContainer POSTGRES = PostgresTestContainer.create();

    @Test
    void shouldStageV12WithoutReplacingV11OrChangingAdultPetJourney()
            throws Exception {
        Flyway.configure()
                .dataSource(
                        POSTGRES.getJdbcUrl(),
                        POSTGRES.getUsername(),
                        POSTGRES.getPassword()
                )
                .target(MigrationVersion.fromVersion("27"))
                .load()
                .migrate();
        seedV27State();

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
                    FROM content_release
                    WHERE content_version = 'chapter-1-v12'
                      AND NOT is_active
                      AND activated_at IS NULL
                      AND content_json ->> 'nodeCount' = '26'
                      AND content_json ->> 'topology' =
                          'adult-pet-frontier-route-v1'
                    """));
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM content_release
                    WHERE content_version = 'chapter-1-v11'
                      AND is_active
                    """));
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM roadmap_user_state
                    WHERE user_id = 'adult-frontier-migration-user'
                      AND state_json ->> 'activePetId' = 'spark-v1'
                      AND state_json #>>
                          '{pets,spark-v1,evolutionStage}' = '2'
                      AND version = 8
                    """));
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM pet_progress
                    WHERE user_id = 'adult-frontier-migration-user'
                      AND pet_id = 'spark-v1'
                      AND level = 3
                      AND bond = 162
                      AND version = 5
                    """));
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM expedition_progress
                    WHERE user_id = 'adult-frontier-migration-user'
                      AND current_node_id = 'uncharted-verge'
                      AND status = 'EVENT_READY'
                      AND unlocked_event_id = 'uncharted-verge-v1'
                      AND version = 11
                    """));
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM content_release
                    WHERE is_active
                    """));
        }
    }

    private void seedV27State() throws Exception {
        try (Connection connection = connection();
             Statement statement = connection.createStatement()) {
            statement.executeUpdate("""
                    INSERT INTO app_user (user_id, created_at, last_seen_at)
                    VALUES ('adult-frontier-migration-user', now(), now())
                    """);
            statement.executeUpdate("""
                    INSERT INTO pet_progress (
                        user_id, pet_id, level, bond,
                        version, created_at, updated_at
                    ) VALUES (
                        'adult-frontier-migration-user', 'spark-v1', 3, 162,
                        5, now(), now()
                    )
                    """);
            statement.executeUpdate("""
                    INSERT INTO roadmap_user_state (
                        user_id, state_json, version, created_at, updated_at
                    ) VALUES (
                        'adult-frontier-migration-user',
                        '{"activePetId":"spark-v1","pets":{"spark-v1":{"level":3,"bond":162,"evolutionStage":2}}}'::jsonb,
                        8, now(), now()
                    )
                    """);
            statement.executeUpdate("""
                    INSERT INTO expedition_progress (
                        user_id, expedition_id, current_node_id,
                        progress_energy, required_energy, status,
                        unlocked_event_id, version, created_at, updated_at
                    ) VALUES (
                        'adult-frontier-migration-user',
                        'starter-expedition-v1', 'uncharted-verge',
                        70, 70, 'EVENT_READY', 'uncharted-verge-v1',
                        11, now(), now()
                    )
                    """);
            statement.executeUpdate(
                    "UPDATE content_release SET is_active = false WHERE is_active"
            );
            statement.executeUpdate("""
                    UPDATE content_release
                    SET is_active = true,
                        activated_at = COALESCE(activated_at, now())
                    WHERE content_version = 'chapter-1-v11'
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
