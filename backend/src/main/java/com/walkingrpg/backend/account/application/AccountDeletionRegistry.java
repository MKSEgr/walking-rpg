package com.walkingrpg.backend.account.application;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.HexFormat;

import com.walkingrpg.backend.operations.JdbcStatementTimeouts;
import org.springframework.jdbc.core.ConnectionCallback;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

@Component
public class AccountDeletionRegistry {

    private static final String ACCOUNT_LOCK_SQL = """
            SELECT pg_advisory_xact_lock(hashtextextended(?, 97))
            """;
    private static final String ACCOUNT_SESSION_LOCK_SQL = """
            SELECT pg_advisory_lock(hashtextextended(?, 97))
            """;
    private static final String ACCOUNT_SESSION_UNLOCK_SQL = """
            SELECT pg_advisory_unlock(hashtextextended(?, 97))
            """;

    private final JdbcTemplate jdbcTemplate;

    public AccountDeletionRegistry(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public String lockSubject(String userId) {
        String normalized = requireUserId(userId);
        jdbcTemplate.execute((ConnectionCallback<Void>) connection -> {
            try (PreparedStatement statement = connection.prepareStatement(ACCOUNT_LOCK_SQL)) {
                JdbcStatementTimeouts.apply(jdbcTemplate, statement);
                statement.setString(1, lockKey(normalized));
                statement.execute();
            }
            return null;
        });
        return subjectHash(normalized);
    }

    public void requireActive(String userId) {
        String subjectHash = lockSubject(userId);
        requireActive(jdbcTemplate, subjectHash);
    }

    public SessionLock lockSession(Connection connection, String userId)
            throws SQLException {
        if (!connection.getAutoCommit()) {
            throw new SQLException(
                    "Account session lock must be acquired before a transaction"
            );
        }
        String normalized = requireUserId(userId);
        String lockKey = lockKey(normalized);
        try (PreparedStatement statement = connection.prepareStatement(
                ACCOUNT_SESSION_LOCK_SQL
        )) {
            JdbcStatementTimeouts.apply(jdbcTemplate, statement);
            statement.setString(1, lockKey);
            statement.execute();
        }
        return new SessionLock(connection, lockKey, subjectHash(normalized));
    }

    private void requireActive(JdbcTemplate template, String subjectHash) {
        Boolean deleted = template.queryForObject("""
                SELECT EXISTS (
                    SELECT 1
                    FROM account_deletion_receipt
                    WHERE subject_hash = ?
                )
                """, Boolean.class, subjectHash);
        if (Boolean.TRUE.equals(deleted)) {
            throw new AccountDeletedException();
        }
    }

    private String lockKey(String normalized) {
        return normalized.length() + ":" + normalized;
    }

    private String subjectHash(String value) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(
                    digest.digest(value.getBytes(StandardCharsets.UTF_8))
            );
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 недоступен", exception);
        }
    }

    private String requireUserId(String value) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException("userId обязателен");
        }
        return value.trim();
    }

    public final class SessionLock implements AutoCloseable {
        private final Connection connection;
        private final String lockKey;
        private final String subjectHash;
        private boolean closed;

        private SessionLock(
                Connection connection,
                String lockKey,
                String subjectHash
        ) {
            this.connection = connection;
            this.lockKey = lockKey;
            this.subjectHash = subjectHash;
        }

        public void requireActive(JdbcTemplate transactionJdbcTemplate) {
            AccountDeletionRegistry.this.requireActive(
                    transactionJdbcTemplate,
                    subjectHash
            );
        }

        @Override
        public void close() throws SQLException {
            if (closed) {
                return;
            }
            try (PreparedStatement statement = connection.prepareStatement(
                    ACCOUNT_SESSION_UNLOCK_SQL
            )) {
                JdbcStatementTimeouts.apply(jdbcTemplate, statement);
                statement.setString(1, lockKey);
                try (ResultSet resultSet = statement.executeQuery()) {
                    if (!resultSet.next() || !resultSet.getBoolean(1)) {
                        throw new SQLException(
                                "Account session advisory lock was not held"
                        );
                    }
                }
            }
            closed = true;
        }
    }
}
