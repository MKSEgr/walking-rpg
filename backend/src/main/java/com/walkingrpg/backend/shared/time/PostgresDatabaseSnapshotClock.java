package com.walkingrpg.backend.shared.time;

import java.sql.Timestamp;
import java.time.Instant;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

@Component
public class PostgresDatabaseSnapshotClock implements DatabaseSnapshotClock {

    private final JdbcTemplate jdbcTemplate;

    public PostgresDatabaseSnapshotClock(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public Instant observe() {
        Timestamp timestamp = jdbcTemplate.queryForObject(
                "SELECT statement_timestamp()",
                Timestamp.class
        );
        if (timestamp == null) {
            throw new IllegalStateException(
                    "Database snapshot clock query returned no timestamp"
            );
        }
        return timestamp.toInstant();
    }
}
