package com.walkingrpg.backend.goal.infrastructure;

import java.time.LocalDate;
import java.util.List;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class JdbcDailyGoalHistoryRepository implements DailyGoalHistoryRepository {

    private final JdbcTemplate jdbcTemplate;

    public JdbcDailyGoalHistoryRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public List<Long> findAcceptedTotals(
            String userId,
            LocalDate fromInclusive,
            LocalDate toExclusive
    ) {
        return jdbcTemplate.queryForList("""
                SELECT accepted_total
                FROM activity_sync_state
                WHERE user_id = ?
                  AND local_date >= ?
                  AND local_date < ?
                  AND accepted_total > 0
                ORDER BY local_date
                """, Long.class, userId, fromInclusive, toExclusive);
    }

    @Override
    public List<LocalDate> findAcceptedDates(
            String userId,
            LocalDate fromInclusive,
            LocalDate toExclusive
    ) {
        return jdbcTemplate.queryForList("""
                SELECT local_date
                FROM activity_sync_state
                WHERE user_id = ?
                  AND local_date >= ?
                  AND local_date < ?
                  AND accepted_total > 0
                ORDER BY local_date
                """, LocalDate.class, userId, fromInclusive, toExclusive);
    }
}
