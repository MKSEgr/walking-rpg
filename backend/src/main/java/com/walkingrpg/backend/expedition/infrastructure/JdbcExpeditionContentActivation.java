package com.walkingrpg.backend.expedition.infrastructure;

import java.util.List;

import com.walkingrpg.backend.expedition.application.ExpeditionContentActivation;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class JdbcExpeditionContentActivation implements ExpeditionContentActivation {

    private final JdbcTemplate jdbcTemplate;

    public JdbcExpeditionContentActivation(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public String activeContentVersion() {
        List<String> versions = jdbcTemplate.queryForList("""
                SELECT content_version
                FROM content_release
                WHERE is_active
                LIMIT 1
                """, String.class);
        return versions.stream().findFirst().orElse(null);
    }
}
