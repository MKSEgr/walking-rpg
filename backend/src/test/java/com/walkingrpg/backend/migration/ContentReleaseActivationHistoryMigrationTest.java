package com.walkingrpg.backend.migration;

import com.walkingrpg.backend.testsupport.PostgresTestContainer;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Timestamp;
import java.time.Instant;

import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.MigrationVersion;
import org.flywaydb.core.api.FlywayException;
import org.junit.jupiter.api.Test;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

@Testcontainers
class ContentReleaseActivationHistoryMigrationTest {

    private static final Instant V1_ACTIVATED_AT =
            Instant.parse("2026-07-30T10:00:00Z");
    private static final Instant V2_ACTIVATED_AT =
            Instant.parse("2026-07-30T12:00:00Z");
    private static final Instant V2_REPUBLISHED_AT =
            Instant.parse("2026-07-30T13:00:00Z");

    @Container
    static final PostgreSQLContainer POSTGRES =
            PostgresTestContainer.create();

    @Test
    void shouldRequireExplicitV14HistoryAndKeepFirstActivationImmutable()
            throws Exception {
        Flyway.configure()
                .dataSource(
                        POSTGRES.getJdbcUrl(),
                        POSTGRES.getUsername(),
                        POSTGRES.getPassword()
                )
                .target(MigrationVersion.fromVersion("14"))
                .load()
                .migrate();

        try (Connection connection = connection();
             Statement statement = connection.createStatement()) {
            statement.executeUpdate("""
                    UPDATE content_release
                    SET created_at = '2026-07-30T10:00:00Z'
                    WHERE content_version = 'chapter-1-v1'
                    """);
            statement.executeUpdate("""
                    UPDATE content_release
                    SET is_active = false
                    WHERE is_active
                    """);
            statement.executeUpdate("""
                    UPDATE content_release
                    SET is_active = true,
                        created_by = 'legacy-admin',
                        created_at = '2026-07-30T13:00:00Z'
                    WHERE content_version = 'chapter-1-v2'
                    """);
        }

        Flyway flyway = Flyway.configure()
                .dataSource(
                        POSTGRES.getJdbcUrl(),
                        POSTGRES.getUsername(),
                        POSTGRES.getPassword()
                )
                .load();
        FlywayException missingHistory = assertThrows(
                FlywayException.class,
                flyway::migrate
        );
        assertTrue(
                missingHistory.getMessage().contains(
                        "explicit chapter-1-v2 first activation timestamp"
                )
        );

        try (Connection connection = connection();
             Statement statement = connection.createStatement()) {
            statement.executeUpdate("""
                    ALTER TABLE content_release
                    ADD COLUMN IF NOT EXISTS activated_at timestamptz
                    """);
            statement.executeUpdate("""
                    UPDATE content_release
                    SET activated_at = '2026-07-30T12:00:00Z'
                    WHERE content_version = 'chapter-1-v2'
                    """);
        }

        flyway.migrate();

        assertEquals("34", flyway.info().current().getVersion().getVersion());
        try (Connection connection = connection();
             Statement statement = connection.createStatement()) {
            assertEquals(V1_ACTIVATED_AT, scalarInstant(statement, """
                    SELECT activated_at
                    FROM content_release
                    WHERE content_version = 'chapter-1-v1'
                    """));
            assertEquals(V2_REPUBLISHED_AT, scalarInstant(statement, """
                    SELECT created_at
                    FROM content_release
                    WHERE content_version = 'chapter-1-v2'
                    """));
            assertEquals(V2_ACTIVATED_AT, scalarInstant(statement, """
                    SELECT activated_at
                    FROM content_release
                    WHERE content_version = 'chapter-1-v2'
                    """));

            statement.executeUpdate("""
                    UPDATE content_release
                    SET created_at = '2026-07-30T14:00:00Z',
                        activated_at = COALESCE(
                            activated_at,
                            '2026-07-30T14:00:00Z'
                        )
                    WHERE content_version = 'chapter-1-v2'
                    """);
            assertEquals(V2_ACTIVATED_AT, scalarInstant(statement, """
                    SELECT activated_at
                    FROM content_release
                    WHERE content_version = 'chapter-1-v2'
                    """));
            assertThrows(SQLException.class, () -> statement.executeUpdate("""
                    UPDATE content_release
                    SET activated_at = '2026-07-30T13:00:00Z'
                    WHERE content_version = 'chapter-1-v2'
                    """));
        }
    }

    private Connection connection() throws Exception {
        return DriverManager.getConnection(
                POSTGRES.getJdbcUrl(),
                POSTGRES.getUsername(),
                POSTGRES.getPassword()
        );
    }

    private Instant scalarInstant(Statement statement, String query)
            throws Exception {
        try (ResultSet result = statement.executeQuery(query)) {
            result.next();
            Timestamp timestamp = result.getTimestamp(1);
            return timestamp == null ? null : timestamp.toInstant();
        }
    }
}
