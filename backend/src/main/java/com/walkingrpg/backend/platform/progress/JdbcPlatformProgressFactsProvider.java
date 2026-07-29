package com.walkingrpg.backend.platform.progress;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class JdbcPlatformProgressFactsProvider implements PlatformProgressFactsProvider {

    private final JdbcTemplate jdbcTemplate;

    public JdbcPlatformProgressFactsProvider(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public PlatformProgressFacts factsFor(String userId) {
        Long steps = jdbcTemplate.queryForObject("""
                SELECT COALESCE(sum(accepted_total), 0)
                FROM activity_sync_state
                WHERE user_id = ?
                """, Long.class, userId);
        Long resolvedEvents = jdbcTemplate.queryForObject("""
                SELECT count(*)
                FROM processed_event_resolution
                WHERE user_id = ?
                """, Long.class, userId);
        Map<String, Integer> petBonds = new LinkedHashMap<>();
        jdbcTemplate.query("""
                SELECT pet_id, bond
                FROM pet_progress
                WHERE user_id = ?
                ORDER BY pet_id
                """, resultSet -> {
            petBonds.put(
                    resultSet.getString("pet_id"),
                    resultSet.getInt("bond")
            );
        }, userId);
        List<String> squads = jdbcTemplate.query("""
                SELECT squad_id::text
                FROM roadmap_squad_member
                WHERE user_id = ?
                LIMIT 1
                """, (resultSet, rowNumber) -> resultSet.getString(1), userId);
        return new PlatformProgressFacts(
                steps == null ? 0 : steps,
                resolvedEvents == null ? 0 : resolvedEvents,
                petBonds,
                squads.stream().findFirst().orElse(null)
        );
    }
}
