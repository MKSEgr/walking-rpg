package com.walkingrpg.backend.migration;

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
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

@Testcontainers
class ProductionProviderIsolationMigrationTest {

    @Container
    static final PostgreSQLContainer POSTGRES =
            new PostgreSQLContainer("postgres:17-alpine");

    @Test
    void shouldDisableDevelopmentCapabilitiesInEveryExistingConfig() throws Exception {
        migrateTo("11");

        try (Connection connection = connection(); Statement statement = connection.createStatement()) {
            assertTrue(scalarBoolean(statement, """
                    SELECT (config_json ->> 'sandboxPaymentsEnabled')::boolean
                    FROM remote_config_snapshot
                    WHERE is_active
                    """));
            statement.executeUpdate("""
                    INSERT INTO remote_config_snapshot (
                        config_version,
                        config_json,
                        is_active,
                        created_by,
                        created_at
                    ) VALUES (
                        'historical-development-config',
                        '{
                          "backgroundHealthSyncEnabled": true,
                          "sandboxPaymentsEnabled": true
                        }'::jsonb,
                        false,
                        'migration-test',
                        now()
                    )
                    """);
        }

        migrateAll();

        try (Connection connection = connection(); Statement statement = connection.createStatement()) {
            assertEquals(2, scalarLong(statement, """
                    SELECT count(*)
                    FROM remote_config_snapshot
                    """));
            assertFalse(scalarBoolean(statement, """
                    SELECT bool_or(
                        (config_json ->> 'sandboxPaymentsEnabled')::boolean
                    )
                    FROM remote_config_snapshot
                    """));
            assertFalse(scalarBoolean(statement, """
                    SELECT bool_or(
                        (config_json ->> 'backgroundHealthSyncEnabled')::boolean
                    )
                    FROM remote_config_snapshot
                    """));
            assertEquals("15", scalarString(statement, """
                    SELECT version
                    FROM flyway_schema_history
                    WHERE success
                    ORDER BY installed_rank DESC
                    LIMIT 1
                    """));
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

    private void migrateAll() {
        Flyway.configure()
                .dataSource(
                        POSTGRES.getJdbcUrl(),
                        POSTGRES.getUsername(),
                        POSTGRES.getPassword()
                )
                .load()
                .migrate();
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

    private boolean scalarBoolean(Statement statement, String sql) throws Exception {
        try (ResultSet result = statement.executeQuery(sql)) {
            result.next();
            return result.getBoolean(1);
        }
    }

    private String scalarString(Statement statement, String sql) throws Exception {
        try (ResultSet result = statement.executeQuery(sql)) {
            result.next();
            return result.getString(1);
        }
    }
}
