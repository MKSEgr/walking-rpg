package com.walkingrpg.backend.account.application;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.sql.PreparedStatement;
import java.util.HexFormat;

import org.springframework.jdbc.core.ConnectionCallback;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

@Component
public class AccountDeletionRegistry {

    private static final String ACCOUNT_LOCK_SQL = """
            SELECT pg_advisory_xact_lock(hashtextextended(?, 97))
            """;

    private final JdbcTemplate jdbcTemplate;

    public AccountDeletionRegistry(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public String lockSubject(String userId) {
        String normalized = requireUserId(userId);
        jdbcTemplate.execute((ConnectionCallback<Void>) connection -> {
            try (PreparedStatement statement = connection.prepareStatement(ACCOUNT_LOCK_SQL)) {
                statement.setString(1, normalized.length() + ":" + normalized);
                statement.execute();
            }
            return null;
        });
        return subjectHash(normalized);
    }

    public void requireActive(String userId) {
        String subjectHash = lockSubject(userId);
        Boolean deleted = jdbcTemplate.queryForObject("""
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
}
