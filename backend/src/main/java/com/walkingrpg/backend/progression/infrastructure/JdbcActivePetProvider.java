package com.walkingrpg.backend.progression.infrastructure;

import java.util.List;

import com.walkingrpg.backend.platform.infrastructure.PlatformRepository;
import com.walkingrpg.backend.progression.application.ActivePetProvider;
import com.walkingrpg.backend.progression.application.ActivePetSelection;
import com.walkingrpg.backend.progression.application.StarterProgressionContent;
import com.walkingrpg.backend.progression.domain.PetDefinition;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class JdbcActivePetProvider implements ActivePetProvider {

    private final JdbcTemplate jdbcTemplate;
    private final StarterProgressionContent content;
    private final PlatformRepository platformRepository;

    public JdbcActivePetProvider(
            JdbcTemplate jdbcTemplate,
            StarterProgressionContent content,
            PlatformRepository platformRepository
    ) {
        this.jdbcTemplate = jdbcTemplate;
        this.content = content;
        this.platformRepository = platformRepository;
    }

    @Override
    public ActivePetSelection activePetFor(String userId) {
        platformRepository.acquireUserLock(userId);
        List<ActivePetSelection> selected = jdbcTemplate.query("""
                SELECT state_json ->> 'activePetId' AS pet_id,
                       COALESCE(
                           jsonb_extract_path_text(
                               state_json,
                               'pets',
                               state_json ->> 'activePetId',
                               'level'
                           )::integer,
                           1
                       ) AS pet_level,
                       COALESCE(
                           jsonb_extract_path_text(
                               state_json,
                               'pets',
                               state_json ->> 'activePetId',
                               'bond'
                           )::integer,
                           10
                       ) AS pet_bond,
                       COALESCE(
                           jsonb_extract_path_text(
                               state_json,
                               'pets',
                               state_json ->> 'activePetId',
                               'evolutionStage'
                           )::integer,
                           0
                       ) AS pet_evolution_stage
                FROM roadmap_user_state
                WHERE user_id = ?
                """, (resultSet, rowNumber) -> new ActivePetSelection(
                resultSet.getString("pet_id"),
                resultSet.getInt("pet_level"),
                resultSet.getInt("pet_bond"),
                resultSet.getInt("pet_evolution_stage")
        ), userId);
        return selected.stream()
                .filter(selection -> content.containsPet(selection.petId()))
                .map(selection -> {
                    PetDefinition definition = content.requirePet(selection.petId());
                    return new ActivePetSelection(
                            selection.petId(),
                            Math.max(selection.level(), definition.initialLevel()),
                            Math.max(selection.bond(), definition.initialBond()),
                            selection.evolutionStage()
                    );
                })
                .findFirst()
                .orElseGet(() -> new ActivePetSelection(
                        StarterProgressionContent.PET_ID,
                        content.pet().initialLevel(),
                        content.pet().initialBond(),
                        0
                ));
    }
}
