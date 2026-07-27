package com.walkingrpg.backend.platform.progress;

import java.util.List;

import com.walkingrpg.backend.progression.application.StarterProgressionContent;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class JdbcPlatformProgressFactsProvider implements PlatformProgressFactsProvider {

    private final JdbcTemplate jdbcTemplate;
    private final StarterProgressionContent progressionContent;

    public JdbcPlatformProgressFactsProvider(
            JdbcTemplate jdbcTemplate,
            StarterProgressionContent progressionContent
    ) {
        this.jdbcTemplate = jdbcTemplate;
        this.progressionContent = progressionContent;
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
        Integer sparkBond = jdbcTemplate.queryForObject("""
                SELECT COALESCE(max(bond), ?)
                FROM pet_progress
                WHERE user_id = ?
                  AND pet_id = ?
                """, Integer.class,
                progressionContent.pet().initialBond(),
                userId,
                progressionContent.pet().petId()
        );
        List<String> squads = jdbcTemplate.query("""
                SELECT squad_id::text
                FROM roadmap_squad_member
                WHERE user_id = ?
                LIMIT 1
                """, (resultSet, rowNumber) -> resultSet.getString(1), userId);
        return new PlatformProgressFacts(
                steps == null ? 0 : steps,
                resolvedEvents == null ? 0 : resolvedEvents,
                sparkBond == null ? progressionContent.pet().initialBond() : sparkBond,
                squads.stream().findFirst().orElse(null)
        );
    }
}
