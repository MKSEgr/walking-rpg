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

@Testcontainers
class FirstJourneyObservabilityMigrationTest {

    @Container
    static final PostgreSQLContainer POSTGRES =
            new PostgreSQLContainer("postgres:17-alpine");

    @Test
    void shouldBackfillLegacyJourneyAndKeepLiveMilestonesDurable() throws Exception {
        migrateTo("8");
        seedLegacyJourney();

        migrateAll();

        try (Connection connection = connection();
             Statement statement = connection.createStatement()) {
            assertEquals(7, scalarLong(statement, """
                    SELECT count(*)
                    FROM first_journey_milestone
                    WHERE user_id = 'legacy-journey-user'
                    """));
            assertEquals(7, scalarLong(statement, """
                    SELECT count(*)
                    FROM first_journey_milestone
                    WHERE user_id = 'legacy-journey-user'
                      AND source = 'BACKFILLED'
                    """));
            assertEquals(0, scalarLong(statement, """
                    SELECT count(*)
                    FROM first_journey_milestone
                    WHERE user_id = 'legacy-journey-user'
                      AND milestone =
                          'FIRST_EVENT_RESULT_ACKNOWLEDGED'
                    """));

            statement.executeUpdate("""
                    INSERT INTO app_user (
                        user_id, created_at, last_seen_at,
                        has_successful_activity_sync
                    ) VALUES (
                        'live-sync-user',
                        '2026-07-29T17:00:00Z',
                        '2026-07-29T17:00:00Z',
                        false
                    )
                    """);
            statement.executeUpdate("""
                    INSERT INTO app_device (
                        user_id, device_id, created_at, last_seen_at
                    ) VALUES (
                        'live-sync-user',
                        'live-device',
                        '2026-07-29T17:00:00Z',
                        '2026-07-29T17:00:00Z'
                    )
                    """);
            statement.executeUpdate("""
                    INSERT INTO processed_activity_sync (
                        user_id, device_id, idempotency_key,
                        request_fingerprint, accepted_total, accepted_delta,
                        energy_granted, risk_status, state_version,
                        server_time, created_at,
                        energy_balance_after, economy_version
                    ) VALUES (
                        'live-sync-user',
                        'live-device',
                        'live-sync-1',
                        repeat('a', 64),
                        0,
                        0,
                        0,
                        'NO_NEW_ACTIVITY',
                        0,
                        '2026-07-29T17:01:00Z',
                        '2026-07-29T17:01:00Z',
                        0,
                        0
                    )
                    """);

            assertEquals("AUTHORITATIVE", scalarString(statement, """
                    SELECT source
                    FROM first_journey_milestone
                    WHERE user_id = 'live-sync-user'
                      AND milestone = 'FIRST_ACTIVITY_SYNC'
                    """));

            statement.executeUpdate("""
                    DELETE FROM app_user
                    WHERE user_id = 'legacy-journey-user'
                    """);
            assertEquals(0, scalarLong(statement, """
                    SELECT count(*)
                    FROM first_journey_milestone
                    WHERE user_id = 'legacy-journey-user'
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

    private void seedLegacyJourney() throws Exception {
        try (Connection connection = connection();
             Statement statement = connection.createStatement()) {
            statement.executeUpdate("""
                    INSERT INTO app_user (
                        user_id, created_at, last_seen_at,
                        has_successful_activity_sync
                    ) VALUES (
                        'legacy-journey-user',
                        '2026-07-29T15:00:00Z',
                        '2026-07-29T15:10:00Z',
                        true
                    )
                    """);
            statement.executeUpdate("""
                    INSERT INTO economy_wallet (
                        user_id, currency_code, balance, version,
                        created_at, updated_at
                    ) VALUES (
                        'legacy-journey-user',
                        'ENERGY',
                        5,
                        1,
                        '2026-07-29T15:00:00Z',
                        '2026-07-29T15:02:00Z'
                    )
                    """);
            statement.executeUpdate("""
                    INSERT INTO economy_ledger (
                        ledger_entry_id, user_id, currency_code, amount,
                        balance_after, wallet_version, reason_code,
                        source_type, source_key, created_at
                    ) VALUES (
                        '11111111-1111-1111-1111-111111111111',
                        'legacy-journey-user',
                        'ENERGY',
                        5,
                        5,
                        1,
                        'ACTIVITY_STEPS',
                        'ACTIVITY_SYNC',
                        'legacy-sync',
                        '2026-07-29T15:02:00Z'
                    )
                    """);
            statement.executeUpdate("""
                    INSERT INTO roadmap_user_state (
                        user_id, state_json, version, created_at, updated_at
                    ) VALUES (
                        'legacy-journey-user',
                        '{
                          "completedOnboardingSteps": [
                            "welcome",
                            "health-permission",
                            "first-sync",
                            "pet-selection",
                            "first-expedition",
                            "first-event"
                          ]
                        }'::jsonb,
                        6,
                        '2026-07-29T15:01:00Z',
                        '2026-07-29T15:09:00Z'
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
