package com.walkingrpg.backend.progression.infrastructure;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;

import com.walkingrpg.backend.progression.domain.PetDefinition;
import com.walkingrpg.backend.progression.domain.PetProgressState;
import com.walkingrpg.backend.progression.domain.PilotDefinition;
import com.walkingrpg.backend.progression.domain.PilotProgressState;
import com.walkingrpg.backend.progression.domain.ProgressionState;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class JdbcProgressionRepository implements ProgressionRepository {

    private final JdbcTemplate jdbcTemplate;

    public JdbcProgressionRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public ProgressionState lockOrCreate(
            String userId,
            PilotDefinition pilot,
            PetDefinition pet,
            Instant observedAt
    ) {
        Timestamp timestamp = Timestamp.from(observedAt);
        jdbcTemplate.update("""
                INSERT INTO pilot_progress (
                    user_id,
                    pilot_id,
                    level,
                    current_experience,
                    next_level_experience,
                    version,
                    created_at,
                    updated_at
                )
                VALUES (?, ?, ?, ?, ?, 0, ?, ?)
                ON CONFLICT (user_id, pilot_id) DO NOTHING
                """,
                userId,
                pilot.pilotId(),
                pilot.initialLevel(),
                pilot.initialExperience(),
                pilot.nextLevelExperience(),
                timestamp,
                timestamp
        );
        jdbcTemplate.update("""
                INSERT INTO pet_progress (
                    user_id,
                    pet_id,
                    level,
                    bond,
                    version,
                    created_at,
                    updated_at
                )
                VALUES (?, ?, ?, ?, 0, ?, ?)
                ON CONFLICT (user_id, pet_id) DO NOTHING
                """,
                userId,
                pet.petId(),
                pet.initialLevel(),
                pet.initialBond(),
                timestamp,
                timestamp
        );

        return new ProgressionState(
                lockPilot(userId, pilot.pilotId()),
                lockPet(userId, pet.petId())
        );
    }

    @Override
    public void save(String userId, ProgressionState state, Instant updatedAt) {
        Timestamp timestamp = Timestamp.from(updatedAt);
        int pilotRows = jdbcTemplate.update("""
                UPDATE pilot_progress
                SET level = ?,
                    current_experience = ?,
                    next_level_experience = ?,
                    version = ?,
                    updated_at = ?
                WHERE user_id = ?
                """,
                state.pilot().level(),
                state.pilot().currentExperience(),
                state.pilot().nextLevelExperience(),
                state.pilot().version(),
                timestamp,
                userId
        );
        int petRows = jdbcTemplate.update("""
                UPDATE pet_progress
                SET level = ?,
                    bond = ?,
                    version = ?,
                    updated_at = ?
                WHERE user_id = ?
                """,
                state.pet().level(),
                state.pet().bond(),
                state.pet().version(),
                timestamp,
                userId
        );
        if (pilotRows != 1 || petRows != 1) {
            throw new IllegalStateException("Не удалось сохранить progression state");
        }
    }

    private PilotProgressState lockPilot(String userId, String pilotId) {
        List<PilotProgressState> states = jdbcTemplate.query("""
                SELECT level,
                       current_experience,
                       next_level_experience,
                       version
                FROM pilot_progress
                WHERE user_id = ?
                  AND pilot_id = ?
                FOR UPDATE
                """, (resultSet, rowNumber) -> new PilotProgressState(
                resultSet.getInt("level"),
                resultSet.getInt("current_experience"),
                resultSet.getInt("next_level_experience"),
                resultSet.getLong("version")
        ), userId, pilotId);
        return states.stream()
                .findFirst()
                .orElseThrow(() -> new IllegalStateException("Pilot progress не создан"));
    }

    private PetProgressState lockPet(String userId, String petId) {
        List<PetProgressState> states = jdbcTemplate.query("""
                SELECT level,
                       bond,
                       version
                FROM pet_progress
                WHERE user_id = ?
                  AND pet_id = ?
                FOR UPDATE
                """, (resultSet, rowNumber) -> new PetProgressState(
                resultSet.getInt("level"),
                resultSet.getInt("bond"),
                resultSet.getLong("version")
        ), userId, petId);
        return states.stream()
                .findFirst()
                .orElseThrow(() -> new IllegalStateException("Pet progress не создан"));
    }
}
