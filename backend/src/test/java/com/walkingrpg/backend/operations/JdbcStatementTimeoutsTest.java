package com.walkingrpg.backend.operations;

import java.sql.Statement;

import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;

import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class JdbcStatementTimeoutsTest {

    @Test
    void shouldApplyConfiguredQueryTimeoutToManualStatement() throws Exception {
        JdbcTemplate jdbcTemplate = mock(JdbcTemplate.class);
        Statement statement = mock(Statement.class);
        when(jdbcTemplate.getQueryTimeout()).thenReturn(10);

        JdbcStatementTimeouts.apply(jdbcTemplate, statement);

        verify(statement).setQueryTimeout(10);
    }

    @Test
    void shouldPreserveDriverDefaultWithoutConfiguredTimeout() throws Exception {
        JdbcTemplate jdbcTemplate = mock(JdbcTemplate.class);
        Statement statement = mock(Statement.class);
        when(jdbcTemplate.getQueryTimeout()).thenReturn(-1);

        JdbcStatementTimeouts.apply(jdbcTemplate, statement);

        verify(statement, never()).setQueryTimeout(anyInt());
    }
}
