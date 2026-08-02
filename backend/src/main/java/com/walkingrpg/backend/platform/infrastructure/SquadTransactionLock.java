package com.walkingrpg.backend.platform.infrastructure;

import java.sql.PreparedStatement;
import java.util.List;

import com.walkingrpg.backend.operations.JdbcStatementTimeouts;
import org.springframework.jdbc.core.ConnectionCallback;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

@Component
public class SquadTransactionLock {

    private static final String SQUAD_LOCK_SQL = """
            SELECT pg_advisory_xact_lock(
                hashtextextended(CAST(? AS uuid)::text, 61)
            ) /* squad-membership-serialization */
            """;

    private final JdbcTemplate jdbcTemplate;

    public SquadTransactionLock(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public void lock(String squadId) {
        jdbcTemplate.execute((ConnectionCallback<Void>) connection -> {
            try (PreparedStatement statement = connection.prepareStatement(SQUAD_LOCK_SQL)) {
                JdbcStatementTimeouts.apply(jdbcTemplate, statement);
                statement.setString(1, squadId);
                statement.execute();
            }
            return null;
        });
    }

    public void lockAffectedByUser(String userId) {
        List<String> squadIds = jdbcTemplate.query("""
                SELECT squad_id::text
                FROM roadmap_squad_member
                WHERE user_id = ?
                UNION
                SELECT squad_id::text
                FROM roadmap_squad
                WHERE owner_user_id = ?
                ORDER BY 1
                """, (resultSet, rowNumber) -> resultSet.getString(1), userId, userId);
        squadIds.forEach(this::lock);
    }
}
