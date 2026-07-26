package com.walkingrpg.backend.expedition.infrastructure;

import java.sql.Timestamp;
import java.util.List;
import java.util.Optional;

import com.walkingrpg.backend.expedition.domain.EventIdempotencyScope;
import com.walkingrpg.backend.expedition.domain.EventPetRewardResult;
import com.walkingrpg.backend.expedition.domain.EventPilotRewardResult;
import com.walkingrpg.backend.expedition.domain.EventResolutionResult;
import com.walkingrpg.backend.expedition.domain.EventResolutionStatus;
import com.walkingrpg.backend.expedition.domain.ExpeditionProgressStatus;
import com.walkingrpg.backend.expedition.domain.ProcessedEventResolution;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class JdbcEventResolutionRepository implements EventResolutionRepository {

    private final JdbcTemplate jdbcTemplate;

    public JdbcEventResolutionRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public Optional<ProcessedEventResolution> findProcessed(EventIdempotencyScope scope) {
        List<ProcessedEventResolution> resolutions = jdbcTemplate.query("""
                SELECT request_fingerprint,
                       content_version,
                       expedition_id,
                       expedition_status,
                       expedition_version,
                       event_title,
                       resolution_status,
                       choice_id,
                       choice_title,
                       outcome_title,
                       outcome_summary,
                       pilot_id,
                       pilot_name,
                       pilot_level_after,
                       pilot_experience_gained,
                       pilot_experience_after,
                       pilot_next_level_experience,
                       pilot_version,
                       pet_id,
                       pet_name,
                       pet_level_after,
                       pet_bond_gained,
                       pet_bond_after,
                       pet_version,
                       server_time
                FROM processed_event_resolution
                WHERE user_id = ?
                  AND event_id = ?
                  AND idempotency_key = ?
                """, (resultSet, rowNumber) -> new ProcessedEventResolution(
                resultSet.getString("request_fingerprint"),
                new EventResolutionResult(
                        resultSet.getString("content_version"),
                        resultSet.getString("expedition_id"),
                        ExpeditionProgressStatus.valueOf(
                                resultSet.getString("expedition_status")
                        ),
                        resultSet.getLong("expedition_version"),
                        scope.eventId(),
                        resultSet.getString("event_title"),
                        EventResolutionStatus.valueOf(
                                resultSet.getString("resolution_status")
                        ),
                        resultSet.getString("choice_id"),
                        resultSet.getString("choice_title"),
                        resultSet.getString("outcome_title"),
                        resultSet.getString("outcome_summary"),
                        new EventPilotRewardResult(
                                resultSet.getString("pilot_id"),
                                resultSet.getString("pilot_name"),
                                resultSet.getInt("pilot_level_after"),
                                resultSet.getInt("pilot_experience_gained"),
                                resultSet.getInt("pilot_experience_after"),
                                resultSet.getInt("pilot_next_level_experience"),
                                resultSet.getLong("pilot_version")
                        ),
                        new EventPetRewardResult(
                                resultSet.getString("pet_id"),
                                resultSet.getString("pet_name"),
                                resultSet.getInt("pet_level_after"),
                                resultSet.getInt("pet_bond_gained"),
                                resultSet.getInt("pet_bond_after"),
                                resultSet.getLong("pet_version")
                        ),
                        resultSet.getTimestamp("server_time").toInstant()
                )
        ), scope.userId(), scope.eventId(), scope.idempotencyKey());
        return resolutions.stream().findFirst();
    }

    @Override
    public void saveProcessed(
            EventIdempotencyScope scope,
            ProcessedEventResolution processed
    ) {
        EventResolutionResult result = processed.result();
        jdbcTemplate.update("""
                INSERT INTO processed_event_resolution (
                    user_id,
                    expedition_id,
                    event_id,
                    idempotency_key,
                    request_fingerprint,
                    content_version,
                    expedition_status,
                    expedition_version,
                    event_title,
                    resolution_status,
                    choice_id,
                    choice_title,
                    outcome_title,
                    outcome_summary,
                    pilot_id,
                    pilot_name,
                    pilot_level_after,
                    pilot_experience_gained,
                    pilot_experience_after,
                    pilot_next_level_experience,
                    pilot_version,
                    pet_id,
                    pet_name,
                    pet_level_after,
                    pet_bond_gained,
                    pet_bond_after,
                    pet_version,
                    server_time,
                    created_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, now())
                """,
                scope.userId(),
                result.expeditionId(),
                scope.eventId(),
                scope.idempotencyKey(),
                processed.requestFingerprint(),
                result.contentVersion(),
                result.expeditionStatus().name(),
                result.expeditionVersion(),
                result.eventTitle(),
                result.status().name(),
                result.choiceId(),
                result.choiceTitle(),
                result.outcomeTitle(),
                result.outcomeSummary(),
                result.pilot().pilotId(),
                result.pilot().name(),
                result.pilot().level(),
                result.pilot().experienceGained(),
                result.pilot().currentExperience(),
                result.pilot().nextLevelExperience(),
                result.pilot().version(),
                result.pet().petId(),
                result.pet().name(),
                result.pet().level(),
                result.pet().bondGained(),
                result.pet().bond(),
                result.pet().version(),
                Timestamp.from(result.serverTime())
        );
    }
}
