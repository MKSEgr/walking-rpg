package com.walkingrpg.backend.expedition.infrastructure;

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
    public boolean isActive(String contentVersion) {
        Boolean active = jdbcTemplate.queryForObject("""
                SELECT EXISTS (
                    SELECT 1
                    FROM content_release
                    WHERE content_version = ?
                      AND is_active
                )
                """, Boolean.class, contentVersion);
        return Boolean.TRUE.equals(active);
    }
}
