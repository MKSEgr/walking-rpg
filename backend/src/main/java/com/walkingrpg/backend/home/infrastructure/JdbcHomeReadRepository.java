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
    public HomeRuntimeState findState(
            String userId,
            LocalDate localDate,
            String expeditionId
    ) {
        HomeRuntimeState state = jdbcTemplate.queryForObject("""
                SELECT COALESCE(activity.accepted_total, 0) AS daily_steps,
                       COALESCE(activity.state_version, 0) AS activity_state_version,
                       activity.time_zone,
                       activity.updated_at AS last_activity_sync_at,
                       COALESCE(wallet.balance, 0) AS available_energy,
                       COALESCE(wallet.version, 0) AS economy_version,
                       COALESCE(expedition.progress_energy, 0) AS expedition_progress,
                       COALESCE(expedition.required_energy, 0) AS expedition_required_energy,
                       expedition.status AS expedition_status,
                       COALESCE(expedition.version, 0) AS expedition_version,
                       expedition.current_node_id,
                       expedition.unlocked_event_id
                FROM (VALUES (1)) AS anchor(value)
                LEFT JOIN activity_sync_state activity
                  ON activity.user_id = ?
                 AND activity.local_date = ?
                LEFT JOIN economy_wallet wallet
                  ON wallet.user_id = ?
                 AND wallet.currency_code = 'ENERGY'
                LEFT JOIN expedition_progress expedition
                  ON expedition.user_id = ?
                 AND expedition.expedition_id = ?
                """, (resultSet, rowNumber) -> {
            Timestamp lastSync = resultSet.getTimestamp("last_activity_sync_at");
            Instant lastActivitySyncAt = lastSync == null ? null : lastSync.toInstant();

            return new HomeRuntimeState(
                    resultSet.getLong("daily_steps"),
                    resultSet.getLong("activity_state_version"),
                    resultSet.getString("time_zone"),
                    lastActivitySyncAt,
                    resultSet.getLong("available_energy"),
                    resultSet.getLong("economy_version"),
                    resultSet.getLong("expedition_progress"),
                    resultSet.getLong("expedition_required_energy"),
                    resultSet.getString("expedition_status"),
                    resultSet.getLong("expedition_version"),
                    resultSet.getString("current_node_id"),
                    resultSet.getString("unlocked_event_id")
            );
        }, userId, localDate, userId, userId, expeditionId);

        if (state == null) {
            throw new IllegalStateException("Home read-model query не вернул строку");
        }
        return state;
    }
}
