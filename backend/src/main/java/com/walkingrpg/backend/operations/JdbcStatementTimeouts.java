package com.walkingrpg.backend.operations;

import java.sql.SQLException;
import java.sql.Statement;
import java.util.Objects;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DataSourceUtils;

public final class JdbcStatementTimeouts {

    private JdbcStatementTimeouts() {
    }

    public static void apply(JdbcTemplate jdbcTemplate, Statement statement)
            throws SQLException {
        DataSourceUtils.applyTimeout(
                statement,
                Objects.requireNonNull(
                        jdbcTemplate.getDataSource(),
                        "JdbcTemplate DataSource is required"
                ),
                jdbcTemplate.getQueryTimeout()
        );
    }
}
