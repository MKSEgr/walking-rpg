package com.walkingrpg.backend.platform.infrastructure;

import java.sql.PreparedStatement;

import com.walkingrpg.backend.operations.JdbcStatementTimeouts;
import org.springframework.jdbc.core.ConnectionCallback;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

@Component
public class PlatformPublicationTransactionLock {

    private static final String PUBLICATION_LOCK_SQL = """
            SELECT pg_advisory_xact_lock(hashtextextended(?, 71))
            /* platform-publication-serialization */
            """;
    private static final String REMOTE_CONFIG_CHANNEL = "remote-config";
    private static final String CONTENT_RELEASE_CHANNEL = "content-release";

    private final JdbcTemplate jdbcTemplate;

    public PlatformPublicationTransactionLock(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public void lockRemoteConfig() {
        lock(REMOTE_CONFIG_CHANNEL);
    }

    public void lockContentRelease() {
        lock(CONTENT_RELEASE_CHANNEL);
    }

    private void lock(String channel) {
        jdbcTemplate.execute((ConnectionCallback<Void>) connection -> {
            try (PreparedStatement statement = connection.prepareStatement(
                    PUBLICATION_LOCK_SQL
            )) {
                JdbcStatementTimeouts.apply(jdbcTemplate, statement);
                statement.setString(1, channel);
                statement.execute();
            }
            return null;
        });
    }
}
