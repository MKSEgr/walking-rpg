package com.walkingrpg.backend.operations;

import java.sql.Connection;
import java.sql.Statement;

import javax.sql.DataSource;

import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.ConnectionHolder;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentCaptor.forClass;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class JdbcStatementTimeoutsTest {

    @Test
    void shouldApplyConfiguredQueryTimeoutToManualStatement() throws Exception {
        JdbcTemplate jdbcTemplate = mock(JdbcTemplate.class);
        DataSource dataSource = mock(DataSource.class);
        Statement statement = mock(Statement.class);
        when(jdbcTemplate.getDataSource()).thenReturn(dataSource);
        when(jdbcTemplate.getQueryTimeout()).thenReturn(10);

        JdbcStatementTimeouts.apply(jdbcTemplate, statement);

        verify(statement).setQueryTimeout(10);
    }

    @Test
    void shouldPreserveDriverDefaultWithoutConfiguredTimeout() throws Exception {
        JdbcTemplate jdbcTemplate = mock(JdbcTemplate.class);
        DataSource dataSource = mock(DataSource.class);
        Statement statement = mock(Statement.class);
        when(jdbcTemplate.getDataSource()).thenReturn(dataSource);
        when(jdbcTemplate.getQueryTimeout()).thenReturn(-1);

        JdbcStatementTimeouts.apply(jdbcTemplate, statement);

        verify(statement, never()).setQueryTimeout(anyInt());
    }

    @Test
    void shouldRespectRemainingTransactionDeadline() throws Exception {
        JdbcTemplate jdbcTemplate = mock(JdbcTemplate.class);
        DataSource dataSource = mock(DataSource.class);
        Statement statement = mock(Statement.class);
        ConnectionHolder connectionHolder =
                new ConnectionHolder(mock(Connection.class));
        connectionHolder.setTimeoutInSeconds(2);
        when(jdbcTemplate.getDataSource()).thenReturn(dataSource);
        when(jdbcTemplate.getQueryTimeout()).thenReturn(10);

        TransactionSynchronizationManager.bindResource(
                dataSource,
                connectionHolder
        );
        try {
            JdbcStatementTimeouts.apply(jdbcTemplate, statement);
        } finally {
            TransactionSynchronizationManager.unbindResource(dataSource);
        }

        var timeout = forClass(Integer.class);
        verify(statement).setQueryTimeout(timeout.capture());
        assertTrue(timeout.getValue() > 0);
        assertTrue(timeout.getValue() <= 2);
    }
}
