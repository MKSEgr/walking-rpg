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
class AdultPetEvolutionMigrationTest {

    @Container
    static final PostgreSQLContainer POSTGRES = PostgresTestContainer.create();

    @Test
    void shouldStageV11WithoutReplacingV10OrChangingPetProgress()
            throws Exception {
        Flyway.configure()
                .dataSource(
                        POSTGRES.getJdbcUrl(),
                        POSTGRES.getUsername(),
                        POSTGRES.getPassword()
                )
                .target(MigrationVersion.fromVersion("26"))
                .load()
                .migrate();
        seedV26State();

        Flyway flyway = Flyway.configure()
                .dataSource(
                        POSTGRES.getJdbcUrl(),
                        POSTGRES.getUsername(),
                        POSTGRES.getPassword()
                )
                .load();
        flyway.migrate();

        assertEquals("27", flyway.info().current().getVersion().getVersion());
        try (Connection connection = connection();
             Statement statement = connection.createStatement()) {
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM content_release
                    WHERE content_version = 'chapter-1-v11'
                      AND NOT is_active
                      AND activated_at IS NULL
                      AND content_json ->> 'nodeCount' = '25'
                      AND content_json ->> 'topology' =
                          'adult-starter-pet-evolution-v1'
                    """));
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM content_release
                    WHERE content_version = 'chapter-1-v10'
                      AND is_active
                    """));
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM roadmap_user_state
                    WHERE user_id = 'adult-evolution-migration-user'
                      AND state_json ->> 'activePetId' = 'spark-v1'
                      AND state_json #>>
                          '{pets,spark-v1,evolutionStage}' = '1'
                      AND state_json #>> '{pets,spark-v1,bond}' = '145'
                      AND version = 7
                    """));
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM pet_progress
                    WHERE user_id = 'adult-evolution-migration-user'
                      AND pet_id = 'spark-v1'
                      AND level = 2
                      AND bond = 145
                      AND version = 4
                    """));
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM content_release
                    WHERE is_active
                    """));
        }
    }

    private void seedV26State() throws Exception {
        try (Connection connection = connection();
             Statement statement = connection.createStatement()) {
            statement.executeUpdate("""
                    INSERT INTO app_user (user_id, created_at, last_seen_at)
                    VALUES ('adult-evolution-migration-user', now(), now())
                    """);
            statement.executeUpdate("""
                    INSERT INTO pet_progress (
                        user_id, pet_id, level, bond,
                        version, created_at, updated_at
                    ) VALUES (
                        'adult-evolution-migration-user', 'spark-v1', 2, 145,
                        4, now(), now()
                    )
                    """);
            statement.executeUpdate("""
                    INSERT INTO roadmap_user_state (
                        user_id, state_json, version, created_at, updated_at
                    ) VALUES (
                        'adult-evolution-migration-user',
                        '{"activePetId":"spark-v1","pets":{"spark-v1":{"level":2,"bond":145,"evolutionStage":1}}}'::jsonb,
                        7, now(), now()
                    )
                    """);
            statement.executeUpdate(
                    "UPDATE content_release SET is_active = false WHERE is_active"
            );
            statement.executeUpdate("""
                    UPDATE content_release
                    SET is_active = true,
                        activated_at = COALESCE(activated_at, now())
                    WHERE content_version = 'chapter-1-v10'
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
