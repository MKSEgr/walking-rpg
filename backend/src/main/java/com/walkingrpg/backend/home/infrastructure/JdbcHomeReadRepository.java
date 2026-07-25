package com.walkingrpg.backend.home.infrastructure;

import java.sql.Timestamp;
import java.time.Instant;
import java.time.LocalDate;

import com.walkingrpg.backend.home.domain.HomeRuntimeState;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class JdbcHomeReadRepository implements HomeReadRepository {

    private final JdbcTemplate jdbcTemplate;

    public JdbcHomeReadRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public HomeRuntimeState findState(String userId, LocalDate localDate) {
        HomeRuntimeState state = jdbcTemplate.queryForObject("""
                SELECT COALESCE(activity.accepted_total, 0) AS daily_steps,
                       COALESCE(activity.state_version, 0) AS activity_state_version,
                       activity.time_zone,
                       activity.updated_at AS last_activity_sync_at,
                       COALESCE(wallet.balance, 0) AS available_energy,
                       COALESCE(wallet.version, 0) AS economy_version
                FROM (VALUES (1)) AS anchor(value)
                LEFT JOIN activity_sync_state activity
                  ON activity.user_id = ?
                 AND activity.local_date = ?
                LEFT JOIN economy_wallet wallet
                  ON wallet.user_id = ?
                 AND wallet.currency_code = 'ENERGY'
                """, (resultSet, rowNumber) -> {
            Timestamp lastSync = resultSet.getTimestamp("last_activity_sync_at");
            Instant lastActivitySyncAt = lastSync == null ? null : lastSync.toInstant();

            return new HomeRuntimeState(
                    resultSet.getLong("daily_steps"),
                    resultSet.getLong("activity_state_version"),
                    resultSet.getString("time_zone"),
                    lastActivitySyncAt,
                    resultSet.getLong("available_energy"),
                    resultSet.getLong("economy_version")
            );
        }, userId, localDate, userId);

        if (state == null) {
            throw new IllegalStateException("Home read-model query не вернул строку");
        }
        return state;
    }
}
