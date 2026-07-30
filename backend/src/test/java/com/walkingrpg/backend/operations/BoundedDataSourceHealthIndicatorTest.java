package com.walkingrpg.backend.operations;

import java.sql.Connection;
import java.sql.SQLException;

import javax.sql.DataSource;

import org.junit.jupiter.api.Test;
import org.springframework.boot.health.contributor.Health;
import org.springframework.boot.health.contributor.Status;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class BoundedDataSourceHealthIndicatorTest {

    @Test
    void shouldUseNonZeroBoundedTimeoutAndReleaseBorrowedConnection()
            throws Exception {
        assertEquals(
                3,
                BoundedDataSourceHealthIndicator.VALIDATION_TIMEOUT_SECONDS
        );
        ManagedDataSource dataSource = mock(ManagedDataSource.class);
        Connection connection = mock(Connection.class);
        when(dataSource.getConnection()).thenReturn(connection);
        when(connection.isValid(3)).thenReturn(true);

        Health health =
                new BoundedDataSourceHealthIndicator(dataSource).health();

        assertEquals(Status.UP, health.getStatus());
        verify(connection).isValid(3);
        verify(connection).close();
        verify(dataSource, never()).close();
    }

    @Test
    void shouldReportDownWhenValidationRejectsConnection() throws Exception {
        DataSource dataSource = mock(DataSource.class);
        Connection connection = mock(Connection.class);
        when(dataSource.getConnection()).thenReturn(connection);
        when(connection.isValid(
                BoundedDataSourceHealthIndicator.VALIDATION_TIMEOUT_SECONDS
        )).thenReturn(false);

        Health health =
                new BoundedDataSourceHealthIndicator(dataSource).health();

        assertEquals(Status.DOWN, health.getStatus());
        verify(connection).close();
    }

    @Test
    void shouldReportDownWhenBoundedValidationFails() throws Exception {
        DataSource dataSource = mock(DataSource.class);
        Connection connection = mock(Connection.class);
        when(dataSource.getConnection()).thenReturn(connection);
        when(connection.isValid(
                BoundedDataSourceHealthIndicator.VALIDATION_TIMEOUT_SECONDS
        )).thenThrow(new SQLException("validation timed out"));

        Health health =
                new BoundedDataSourceHealthIndicator(dataSource).health();

        assertEquals(Status.DOWN, health.getStatus());
        verify(connection).close();
    }

    private interface ManagedDataSource extends DataSource, AutoCloseable {

        @Override
        void close();
    }
}
