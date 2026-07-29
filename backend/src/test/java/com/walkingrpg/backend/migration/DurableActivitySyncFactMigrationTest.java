package com.walkingrpg.backend.migration;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Statement;

import org.flywaydb.core.Flyway;
import org.flywaydb.core.api.MigrationVersion;
import org.junit.jupiter.api.Test;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

@Testcontainers
class DurableActivitySyncFactMigrationTest {

    @Container
    static final PostgreSQLContainer POSTGRES =
            new PostgreSQLContainer("postgres:17-alpine");

    @Test
    void shouldBackfillOnlyUsersWithActivitySpecificEvidence() throws Exception {
        migrateTo("7");
        seedHistoricalUsers();

        migrateAll();

        try (Connection connection = connection()) {
            assertTrue(successfulSyncMarker(connection, "state-user"));
            assertTrue(successfulSyncMarker(connection, "receipt-user"));
            assertTrue(successfulSyncMarker(connection, "risk-user"));
            assertFalse(successfulSyncMarker(connection, "push-only-user"));
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

    private void seedHistoricalUsers() throws Exception {
        try (Connection connection = connection();
             Statement statement = connection.createStatement()) {
            statement.executeUpdate("""
                    INSERT INTO app_user (user_id, created_at, last_seen_at)
                    VALUES
                        ('state-user', now(), now()),
                        ('receipt-user', now(), now()),
                        ('risk-user', now(), now()),
                        ('push-only-user', now(), now())
                    """);
            statement.executeUpdate("""
                    INSERT INTO app_device (
                        user_id, device_id, created_at, last_seen_at
                    ) VALUES
                        ('receipt-user', 'receipt-device', now(), now()),
                        ('risk-user', 'risk-device', now(), now()),
                        ('push-only-user', 'push-device', now(), now())
                    """);
            statement.executeUpdate("""
                    INSERT INTO activity_sync_state (
                        user_id, local_date, accepted_total, state_version,
                        time_zone, updated_at
                    ) VALUES (
                        'state-user', DATE '2026-07-28', 100, 1,
                        'Europe/Berlin', now()
                    )
                    """);
            statement.executeUpdate("""
                    INSERT INTO processed_activity_sync (
                        user_id, device_id, idempotency_key,
                        request_fingerprint, accepted_total, accepted_delta,
                        energy_granted, energy_balance_after, economy_version,
                        risk_status, state_version, server_time, created_at
                    ) VALUES (
                        'receipt-user', 'receipt-device', 'zero-sync',
                        repeat('a', 64), 0, 0, 0, 0, 0,
                        'NO_NEW_ACTIVITY', 0, now(), now()
                    )
                    """);
            statement.executeUpdate("""
                    INSERT INTO activity_risk_assessment (
                        user_id, device_id, local_date, authoritative_total,
                        accepted_delta, risk_score, decision, signals,
                        created_at
                    ) VALUES (
                        'risk-user', 'risk-device', DATE '2026-07-28', 0,
                        0, 0, 'ACCEPT', '[]'::jsonb, now()
                    )
                    """);
        }
    }

    private boolean successfulSyncMarker(Connection connection, String userId)
            throws Exception {
        try (PreparedStatement statement = connection.prepareStatement("""
                SELECT has_successful_activity_sync
                FROM app_user
                WHERE user_id = ?
                """)) {
            statement.setString(1, userId);
            try (ResultSet result = statement.executeQuery()) {
                result.next();
                return result.getBoolean(1);
            }
        }
    }

    private Connection connection() throws Exception {
        return DriverManager.getConnection(
                POSTGRES.getJdbcUrl(),
                POSTGRES.getUsername(),
                POSTGRES.getPassword()
        );
    }
}
