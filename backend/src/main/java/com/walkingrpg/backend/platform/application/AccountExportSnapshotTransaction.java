package com.walkingrpg.backend.platform.application;

import java.sql.Connection;
import java.sql.SQLException;
import java.util.Objects;
import java.util.function.Function;

import com.walkingrpg.backend.account.application.AccountDeletionRegistry;
import org.springframework.jdbc.core.ConnectionCallback;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.SingleConnectionDataSource;
import org.springframework.stereotype.Component;

@Component
public class AccountExportSnapshotTransaction {

    private final JdbcTemplate jdbcTemplate;
    private final AccountDeletionRegistry accountDeletionRegistry;

    public AccountExportSnapshotTransaction(
            JdbcTemplate jdbcTemplate,
            AccountDeletionRegistry accountDeletionRegistry
    ) {
        this.jdbcTemplate = jdbcTemplate;
        this.accountDeletionRegistry = accountDeletionRegistry;
    }

    public <T> T read(String userId, Function<JdbcTemplate, T> reader) {
        Objects.requireNonNull(reader, "reader is required");
        return jdbcTemplate.execute((ConnectionCallback<T>) connection ->
                read(connection, userId, reader));
    }

    private <T> T read(
            Connection connection,
            String userId,
            Function<JdbcTemplate, T> reader
    ) throws SQLException {
        ConnectionState original = ConnectionState.capture(connection);
        if (!original.autoCommit()) {
            throw new SQLException(
                    "Account export snapshot requires an unbound connection"
            );
        }
        AccountDeletionRegistry.SessionLock subjectLock = null;
        boolean subjectLockAttempted = false;
        Throwable failure = null;
        try {
            subjectLockAttempted = true;
            subjectLock = accountDeletionRegistry.lockSession(connection, userId);
            connection.setTransactionIsolation(Connection.TRANSACTION_REPEATABLE_READ);
            connection.setReadOnly(true);
            connection.setAutoCommit(false);

            JdbcTemplate snapshotJdbcTemplate = snapshotJdbcTemplate(connection);
            subjectLock.requireActive(snapshotJdbcTemplate);
            T result = reader.apply(snapshotJdbcTemplate);
            connection.commit();
            return result;
        } catch (SQLException | RuntimeException | Error exception) {
            failure = exception;
            rollback(connection, exception);
            throw exception;
        } finally {
            cleanup(
                    connection,
                    subjectLock,
                    original,
                    failure,
                    subjectLockAttempted && subjectLock == null
            );
        }
    }

    private JdbcTemplate snapshotJdbcTemplate(Connection connection) {
        JdbcTemplate snapshot = new JdbcTemplate(
                new SingleConnectionDataSource(connection, true)
        );
        snapshot.setQueryTimeout(jdbcTemplate.getQueryTimeout());
        return snapshot;
    }

    private static void rollback(Connection connection, Throwable failure) {
        try {
            if (!connection.getAutoCommit()) {
                connection.rollback();
            }
        } catch (SQLException rollbackFailure) {
            failure.addSuppressed(rollbackFailure);
        }
    }

    private static void cleanup(
            Connection connection,
            AccountDeletionRegistry.SessionLock subjectLock,
            ConnectionState original,
            Throwable failure,
            boolean uncertainSessionLock
    ) throws SQLException {
        SQLException cleanupFailure = uncertainSessionLock
                ? new SQLException("Account session lock state is uncertain")
                : null;
        try {
            if (!connection.getAutoCommit()) {
                connection.setAutoCommit(true);
            }
        } catch (SQLException exception) {
            cleanupFailure = exception;
        }
        try {
            connection.setReadOnly(original.readOnly());
        } catch (SQLException exception) {
            cleanupFailure = append(cleanupFailure, exception);
        }
        try {
            connection.setTransactionIsolation(original.isolation());
        } catch (SQLException exception) {
            cleanupFailure = append(cleanupFailure, exception);
        }
        if (subjectLock != null) {
            try {
                subjectLock.close();
            } catch (SQLException exception) {
                cleanupFailure = append(cleanupFailure, exception);
            }
        }
        if (cleanupFailure == null) {
            return;
        }

        try {
            connection.abort(Runnable::run);
        } catch (SQLException | RuntimeException abortFailure) {
            cleanupFailure.addSuppressed(abortFailure);
        }
        if (failure != null) {
            failure.addSuppressed(cleanupFailure);
            return;
        }
        throw cleanupFailure;
    }

    private static SQLException append(
            SQLException existing,
            SQLException additional
    ) {
        if (existing == null) {
            return additional;
        }
        existing.addSuppressed(additional);
        return existing;
    }

    private record ConnectionState(
            boolean autoCommit,
            boolean readOnly,
            int isolation
    ) {
        private static ConnectionState capture(Connection connection)
                throws SQLException {
            return new ConnectionState(
                    connection.getAutoCommit(),
                    connection.isReadOnly(),
                    connection.getTransactionIsolation()
            );
        }
    }
}
