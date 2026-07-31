package com.walkingrpg.backend.expedition.infrastructure;

import java.sql.PreparedStatement;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.Optional;

import com.walkingrpg.backend.expedition.domain.ExpeditionAdvanceResult;
import com.walkingrpg.backend.expedition.domain.ExpeditionEventDefinition;
import com.walkingrpg.backend.expedition.domain.ExpeditionIdempotencyScope;
import com.walkingrpg.backend.expedition.domain.ExpeditionProgressState;
import com.walkingrpg.backend.expedition.domain.ExpeditionProgressStatus;
import com.walkingrpg.backend.expedition.domain.ProcessedExpeditionAdvance;
import com.walkingrpg.backend.operations.JdbcStatementTimeouts;
import org.springframework.jdbc.core.ConnectionCallback;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class JdbcExpeditionRepository implements ExpeditionRepository {

    private static final String LOCK_SQL = """
            SELECT pg_advisory_xact_lock(hashtextextended(?, 0))
            """;

    private final JdbcTemplate jdbcTemplate;

    public JdbcExpeditionRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public void acquireLock(String userId, String expeditionId) {
        String lockKey = userId.length()
                + ":"
                + userId
                + ":"
                + expeditionId;
        jdbcTemplate.execute((ConnectionCallback<Void>) connection -> {
            try (PreparedStatement statement = connection.prepareStatement(LOCK_SQL)) {
                JdbcStatementTimeouts.apply(jdbcTemplate, statement);
                statement.setString(1, lockKey);
                statement.execute();
            }
            return null;
        });
    }

    @Override
    public Optional<ExpeditionProgressState> findState(
            String userId,
            String expeditionId
    ) {
        List<ExpeditionProgressState> states = jdbcTemplate.query("""
                SELECT progress_energy,
                       required_energy,
                       status,
                       current_node_id,
                       unlocked_event_id,
                       version
                FROM expedition_progress
                WHERE user_id = ?
                  AND expedition_id = ?
                """, (resultSet, rowNumber) -> new ExpeditionProgressState(
                resultSet.getLong("progress_energy"),
                resultSet.getLong("required_energy"),
                ExpeditionProgressStatus.valueOf(resultSet.getString("status")),
                resultSet.getString("current_node_id"),
                resultSet.getString("unlocked_event_id"),
                resultSet.getLong("version")
        ), userId, expeditionId);
        return states.stream().findFirst();
    }

    @Override
    public void saveState(
            String userId,
            String expeditionId,
            ExpeditionProgressState state,
            Instant updatedAt
    ) {
        Timestamp timestamp = Timestamp.from(updatedAt);
        jdbcTemplate.update("""
                INSERT INTO expedition_progress (
                    user_id,
                    expedition_id,
                    current_node_id,
                    progress_energy,
                    required_energy,
                    status,
                    unlocked_event_id,
                    version,
                    created_at,
                    updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT (user_id, expedition_id) DO UPDATE
                SET current_node_id = EXCLUDED.current_node_id,
                    progress_energy = EXCLUDED.progress_energy,
                    required_energy = EXCLUDED.required_energy,
                    status = EXCLUDED.status,
                    unlocked_event_id = EXCLUDED.unlocked_event_id,
                    version = EXCLUDED.version,
                    updated_at = EXCLUDED.updated_at
                """,
                userId,
                expeditionId,
                state.currentNodeId(),
                state.progressEnergy(),
                state.requiredEnergy(),
                state.status().name(),
                state.unlockedEventId(),
                state.version(),
                timestamp,
                timestamp
        );
    }

    @Override
    public Optional<ProcessedExpeditionAdvance> findProcessed(
            ExpeditionIdempotencyScope scope
    ) {
        List<ProcessedExpeditionAdvance> commands = jdbcTemplate.query("""
                SELECT request_fingerprint,
                       content_version,
                       expedition_name,
                       energy_spent,
                       energy_balance_after,
                       economy_version,
                       progress_after,
                       required_energy,
                       expedition_version,
                       expedition_status,
                       current_node_id,
                       current_node_name,
                       event_id,
                       event_title,
                       event_summary,
                       server_time
                FROM processed_expedition_advance
                WHERE user_id = ?
                  AND expedition_id = ?
                  AND idempotency_key = ?
                """, (resultSet, rowNumber) -> {
            String eventId = resultSet.getString("event_id");
            ExpeditionEventDefinition event = eventId == null
                    ? null
                    : new ExpeditionEventDefinition(
                            eventId,
                            resultSet.getString("event_title"),
                            resultSet.getString("event_summary")
                    );
            return new ProcessedExpeditionAdvance(
                    resultSet.getString("request_fingerprint"),
                    new ExpeditionAdvanceResult(
                            resultSet.getString("content_version"),
                            scope.expeditionId(),
                            resultSet.getString("expedition_name"),
                            resultSet.getLong("energy_spent"),
                            resultSet.getLong("energy_balance_after"),
                            resultSet.getLong("economy_version"),
                            resultSet.getLong("progress_after"),
                            resultSet.getLong("required_energy"),
                            resultSet.getLong("expedition_version"),
                            ExpeditionProgressStatus.valueOf(
                                    resultSet.getString("expedition_status")
                            ),
                            resultSet.getString("current_node_id"),
                            resultSet.getString("current_node_name"),
                            event,
                            resultSet.getTimestamp("server_time").toInstant()
                    )
            );
        }, scope.userId(), scope.expeditionId(), scope.idempotencyKey());
        return commands.stream().findFirst();
    }

    @Override
    public void saveProcessed(
            ExpeditionIdempotencyScope scope,
            ProcessedExpeditionAdvance processed
    ) {
        ExpeditionAdvanceResult result = processed.result();
        ExpeditionEventDefinition event = result.unlockedEvent();
        jdbcTemplate.update("""
                INSERT INTO processed_expedition_advance (
                    user_id,
                    expedition_id,
                    idempotency_key,
                    request_fingerprint,
                    content_version,
                    expedition_name,
                    energy_spent,
                    energy_balance_after,
                    economy_version,
                    progress_after,
                    required_energy,
                    expedition_version,
                    expedition_status,
                    current_node_id,
                    current_node_name,
                    event_id,
                    event_title,
                    event_summary,
                    server_time,
                    created_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, now())
                """,
                scope.userId(),
                scope.expeditionId(),
                scope.idempotencyKey(),
                processed.requestFingerprint(),
                result.contentVersion(),
                result.expeditionName(),
                result.energySpent(),
                result.energyBalanceAfter(),
                result.economyVersion(),
                result.progressAfter(),
                result.requiredEnergy(),
                result.expeditionVersion(),
                result.status().name(),
                result.currentNodeId(),
                result.currentNodeName(),
                event == null ? null : event.eventId(),
                event == null ? null : event.title(),
                event == null ? null : event.summary(),
                Timestamp.from(result.serverTime())
        );
    }
}
