package com.walkingrpg.backend.activity.retention;

import java.sql.Timestamp;
import java.time.Instant;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class JdbcActivityRetentionRepository implements ActivityRetentionRepository {

    private final JdbcTemplate jdbcTemplate;

    public JdbcActivityRetentionRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public int deleteProcessedBefore(Instant cutoff) {
        return jdbcTemplate.update("""
                DELETE FROM processed_activity_sync
                WHERE created_at < ?
                """, Timestamp.from(cutoff));
    }
}
