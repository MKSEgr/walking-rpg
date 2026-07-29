package com.walkingrpg.backend.activity.infrastructure;

import java.sql.PreparedStatement;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;

import com.walkingrpg.backend.account.application.AccountDeletionRegistry;
import com.walkingrpg.backend.activity.domain.ActivityDayKey;
import com.walkingrpg.backend.activity.domain.ActivityDayState;
import com.walkingrpg.backend.activity.domain.ActivityRiskStatus;
import com.walkingrpg.backend.activity.domain.ActivitySyncOutcome;
import com.walkingrpg.backend.activity.domain.ActivitySyncResult;
import com.walkingrpg.backend.activity.domain.IdempotencyScope;
import com.walkingrpg.backend.activity.domain.ProcessedActivitySync;
import org.springframework.jdbc.core.ConnectionCallback;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class JdbcActivitySyncRepository implements ActivitySyncRepository {

    private static final String USER_LOCK_SQL = """
            SELECT pg_advisory_xact_lock(hashtextextended(?, 0))
            """;

    private final JdbcTemplate jdbcTemplate;
    private final AccountDeletionRegistry accountDeletionRegistry;

    public JdbcActivitySyncRepository(
            JdbcTemplate jdbcTemplate,
            AccountDeletionRegistry accountDeletionRegistry
    ) {
        this.jdbcTemplate = jdbcTemplate;
        this.accountDeletionRegistry = accountDeletionRegistry;
    }

    @Override
    public void acquireUserLock(String userId) {
        String lockKey = userId.length() + ":" + userId;
        jdbcTemplate.execute((ConnectionCallback<Void>) connection -> {
            try (PreparedStatement statement = connection.prepareStatement(USER_LOCK_SQL)) {
                statement.setString(1, lockKey);
                statement.execute();
            }
            return null;
        });
    }

    @Override
    public void registerDevice(String userId, String deviceId, Instant seenAt) {
        accountDeletionRegistry.requireActive(userId);
        Timestamp timestamp = Timestamp.from(seenAt);
        jdbcTemplate.update("""
                INSERT INTO app_user (user_id, created_at, last_seen_at)
                VALUES (?, ?, ?)
                ON CONFLICT (user_id) DO UPDATE
                SET last_seen_at = GREATEST(app_user.last_seen_at, EXCLUDED.last_seen_at)
                """, userId, timestamp, timestamp);

        jdbcTemplate.update("""
                INSERT INTO app_device (user_id, device_id, created_at, last_seen_at)
                VALUES (?, ?, ?, ?)
                ON CONFLICT (user_id, device_id) DO UPDATE
                SET last_seen_at = GREATEST(app_device.last_seen_at, EXCLUDED.last_seen_at)
                """, userId, deviceId, timestamp, timestamp);
    }

    @Override
    public Optional<ActivityDayState> findState(ActivityDayKey key) {
        List<ActivityDayState> states = jdbcTemplate.query("""
                SELECT accepted_total, state_version
                FROM activity_sync_state
                WHERE user_id = ?
                  AND local_date = ?
                """, (resultSet, rowNumber) -> new ActivityDayState(
                resultSet.getLong("accepted_total"),
                resultSet.getLong("state_version")
        ), key.userId(), key.localDate());
        return states.stream().findFirst();
    }

    @Override
    public void saveState(ActivityDayKey key, ActivityDayState state, ZoneId timeZone) {
        jdbcTemplate.update("""
                INSERT INTO activity_sync_state (
                    user_id,
                    local_date,
                    accepted_total,
                    state_version,
                    time_zone,
                    updated_at
                )
                VALUES (?, ?, ?, ?, ?, now())
                ON CONFLICT (user_id, local_date) DO UPDATE
                SET accepted_total = EXCLUDED.accepted_total,
                    state_version = EXCLUDED.state_version,
                    time_zone = EXCLUDED.time_zone,
                    updated_at = now()
                """,
                key.userId(),
                key.localDate(),
                state.acceptedTotal(),
                state.stateVersion(),
                timeZone.getId()
        );
    }

    @Override
    public Optional<ProcessedActivitySync> findProcessed(IdempotencyScope scope) {
        List<ProcessedActivitySync> processed = jdbcTemplate.query("""
                SELECT request_fingerprint,
                       accepted_total,
                       accepted_delta,
                       energy_granted,
                       energy_balance_after,
                       economy_version,
                       risk_status,
                       state_version,
                       server_time
                FROM processed_activity_sync
                WHERE user_id = ?
                  AND device_id = ?
                  AND idempotency_key = ?
                """, (resultSet, rowNumber) -> new ProcessedActivitySync(
                resultSet.getString("request_fingerprint"),
                new ActivitySyncOutcome(
                        new ActivitySyncResult(
                                resultSet.getLong("accepted_total"),
                                resultSet.getLong("accepted_delta"),
                                resultSet.getLong("energy_granted"),
                                ActivityRiskStatus.valueOf(resultSet.getString("risk_status")),
                                resultSet.getLong("state_version"),
                                resultSet.getTimestamp("server_time").toInstant()
                        ),
                        resultSet.getLong("energy_balance_after"),
                        resultSet.getLong("economy_version")
                )
        ), scope.userId(), scope.deviceId(), scope.idempotencyKey());
        return processed.stream().findFirst();
    }

    @Override
    public void saveProcessed(
            IdempotencyScope scope,
            ProcessedActivitySync processedSync
    ) {
        ActivitySyncOutcome outcome = processedSync.outcome();
        ActivitySyncResult result = outcome.activity();
        jdbcTemplate.update("""
                INSERT INTO processed_activity_sync (
                    user_id,
                    device_id,
                    idempotency_key,
                    request_fingerprint,
                    accepted_total,
                    accepted_delta,
                    energy_granted,
                    energy_balance_after,
                    economy_version,
                    risk_status,
                    state_version,
                    server_time,
                    created_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, now())
                """,
                scope.userId(),
                scope.deviceId(),
                scope.idempotencyKey(),
                processedSync.requestFingerprint(),
                result.acceptedTotal(),
                result.acceptedDelta(),
                result.energyGranted(),
                outcome.energyBalanceAfter(),
                outcome.economyVersion(),
                result.riskStatus().name(),
                result.stateVersion(),
                Timestamp.from(result.serverTime())
        );
    }

    @Override
    public void markSuccessfulSync(String userId) {
        int updated = jdbcTemplate.update("""
                UPDATE app_user
                SET has_successful_activity_sync = true
                WHERE user_id = ?
                """, userId);
        if (updated != 1) {
            throw new IllegalStateException(
                    "Не удалось сохранить факт успешной синхронизации"
            );
        }
    }
}
