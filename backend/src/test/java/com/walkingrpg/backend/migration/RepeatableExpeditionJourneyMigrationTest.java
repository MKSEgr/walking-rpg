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
class RepeatableExpeditionJourneyMigrationTest {

    @Container
    static final PostgreSQLContainer POSTGRES = PostgresTestContainer.create();

    @Test
    void shouldBackfillFirstJourneyWithoutChangingCompletedProgress()
            throws Exception {
        Flyway.configure()
                .dataSource(
                        POSTGRES.getJdbcUrl(),
                        POSTGRES.getUsername(),
                        POSTGRES.getPassword()
                )
                .target(MigrationVersion.fromVersion("33"))
                .load()
                .migrate();
        seedCompletedJourney();

        Flyway flyway = Flyway.configure()
                .dataSource(
                        POSTGRES.getJdbcUrl(),
                        POSTGRES.getUsername(),
                        POSTGRES.getPassword()
                )
                .load();
        flyway.migrate();

        assertEquals("34", flyway.info().current().getVersion().getVersion());
        try (Connection connection = connection();
             Statement statement = connection.createStatement()) {
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM expedition_journey_cycle
                    WHERE user_id = 'repeat-journey-migration-user'
                      AND expedition_id = 'starter-expedition-v1'
                      AND journey_number = 1
                    """));
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM expedition_progress
                    WHERE user_id = 'repeat-journey-migration-user'
                      AND current_node_id = 'first-light-causeway'
                      AND progress_energy = 105
                      AND required_energy = 105
                      AND status = 'COMPLETED'
                      AND unlocked_event_id = 'first-light-causeway-v1'
                      AND version = 60
                    """));
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM information_schema.columns
                    WHERE table_schema = 'public'
                      AND table_name = 'processed_event_resolution'
                      AND column_name = 'journey_number'
                    """));
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM pg_constraint
                    WHERE conname = 'uq_processed_event_once_per_journey'
                      AND pg_get_constraintdef(oid) =
                          'UNIQUE (user_id, expedition_id, event_id, journey_number)'
                    """));
            assertEquals(0, scalar(statement, """
                    SELECT count(*)
                    FROM pg_constraint
                    WHERE conname = 'uq_processed_event_once'
                    """));
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM information_schema.tables
                    WHERE table_schema = 'public'
                      AND table_name = 'processed_expedition_journey_start'
                    """));
        }
    }

    private void seedCompletedJourney() throws Exception {
        try (Connection connection = connection();
             Statement statement = connection.createStatement()) {
            statement.executeUpdate("""
                    INSERT INTO app_user (user_id, created_at, last_seen_at)
                    VALUES ('repeat-journey-migration-user', now(), now())
                    """);
            statement.executeUpdate("""
                    INSERT INTO expedition_progress (
                        user_id, expedition_id, current_node_id,
                        progress_energy, required_energy, status,
                        unlocked_event_id, version, created_at, updated_at
                    ) VALUES (
                        'repeat-journey-migration-user',
                        'starter-expedition-v1', 'first-light-causeway',
                        105, 105, 'COMPLETED',
                        'first-light-causeway-v1', 60, now(), now()
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

    private int scalar(Statement statement, String sql) throws Exception {
        try (ResultSet result = statement.executeQuery(sql)) {
            result.next();
            return result.getInt(1);
        }
    }
}
