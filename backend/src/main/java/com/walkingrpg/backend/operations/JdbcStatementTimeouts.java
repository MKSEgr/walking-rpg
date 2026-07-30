package com.walkingrpg.backend.operations;

import java.sql.SQLException;
import java.sql.Statement;

import org.springframework.jdbc.core.JdbcTemplate;

public final class JdbcStatementTimeouts {

    private JdbcStatementTimeouts() {
    }

    public static void apply(JdbcTemplate jdbcTemplate, Statement statement)
            throws SQLException {
        int queryTimeout = jdbcTemplate.getQueryTimeout();
        if (queryTimeout > 0) {
            statement.setQueryTimeout(queryTimeout);
        }
    }
}
