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
class StormRiftRouteMigrationTest {

    @Container
    static final PostgreSQLContainer POSTGRES = PostgresTestContainer.create();

    @Test
    void shouldStageChapterV3WithoutReplacingActiveChapterV2() throws Exception {
        Flyway.configure()
                .dataSource(
                        POSTGRES.getJdbcUrl(),
                        POSTGRES.getUsername(),
                        POSTGRES.getPassword()
                )
                .target(MigrationVersion.fromVersion("17"))
                .load()
                .migrate();

        try (Connection connection = connection();
             Statement statement = connection.createStatement()) {
            statement.executeUpdate(
                    "UPDATE content_release SET is_active = false WHERE is_active"
            );
            statement.executeUpdate("""
                    UPDATE content_release
                    SET is_active = true,
                        activated_at = COALESCE(activated_at, now())
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
        flyway.migrate();

        assertEquals("30", flyway.info().current().getVersion().getVersion());
        try (Connection connection = connection();
             Statement statement = connection.createStatement()) {
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM content_release
                    WHERE content_version = 'chapter-1-v3'
                      AND NOT is_active
                      AND activated_at IS NULL
                      AND content_json ->> 'nodeCount' = '20'
                      AND content_json ->> 'topology' = 'storm-rift-v1'
                    """));
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM content_release
                    WHERE content_version = 'chapter-1-v2'
                      AND is_active
                      AND activated_at IS NOT NULL
                    """));
            assertEquals(1, scalar(statement, """
                    SELECT count(*)
                    FROM content_release
                    WHERE is_active
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

    private long scalar(Statement statement, String query) throws Exception {
        try (ResultSet result = statement.executeQuery(query)) {
            result.next();
            return result.getLong(1);
        }
    }
}
