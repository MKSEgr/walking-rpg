package com.walkingrpg.backend.expedition.infrastructure;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.function.Supplier;

import com.walkingrpg.backend.account.application.AccountDeletionRegistry;
import com.walkingrpg.backend.expedition.domain.EventIdempotencyScope;
import com.walkingrpg.backend.expedition.domain.EventMaterialRewardResult;
import com.walkingrpg.backend.expedition.domain.EventNextNodeResult;
import com.walkingrpg.backend.expedition.domain.EventPetRewardResult;
import com.walkingrpg.backend.expedition.domain.EventPilotRewardResult;
import com.walkingrpg.backend.expedition.domain.EventResultAcknowledgementResult;
import com.walkingrpg.backend.expedition.domain.EventResolutionResult;
import com.walkingrpg.backend.expedition.domain.EventResolutionStatus;
import com.walkingrpg.backend.expedition.domain.ExpeditionProgressStatus;
import com.walkingrpg.backend.expedition.domain.ProcessedEventResolution;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class JdbcEventResolutionRepository implements EventResolutionRepository {

    private static final String RESULT_COLUMNS = """
            receipt_id,
            event_id,
            request_fingerprint,
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
            material_item_id,
            material_item_name,
            material_item_description,
            material_quantity_gained,
            material_quantity_after,
            material_version,
            handoff_required,
            next_node_id,
            next_node_name,
            server_time
            """;

    private final JdbcTemplate jdbcTemplate;
    private final AccountDeletionRegistry accountDeletionRegistry;

    public JdbcEventResolutionRepository(
            JdbcTemplate jdbcTemplate,
            AccountDeletionRegistry accountDeletionRegistry
    ) {
        this.jdbcTemplate = jdbcTemplate;
        this.accountDeletionRegistry = accountDeletionRegistry;
    }

    @Override
    public Optional<ProcessedEventResolution> findProcessed(EventIdempotencyScope scope) {
        List<ProcessedEventResolution> resolutions = jdbcTemplate.query("""
                SELECT %s
                FROM processed_event_resolution
                WHERE user_id = ?
                  AND event_id = ?
                  AND idempotency_key = ?
                """.formatted(RESULT_COLUMNS), this::mapProcessed,
                scope.userId(), scope.eventId(), scope.idempotencyKey());
        return resolutions.stream().findFirst();
    }

    @Override
    public Optional<ProcessedEventResolution> findPendingResult(
            String userId,
            String expeditionId
    ) {
        List<ProcessedEventResolution> resolutions = jdbcTemplate.query("""
                SELECT %s
                FROM processed_event_resolution
                WHERE user_id = ?
                  AND expedition_id = ?
                  AND handoff_required
                  AND acknowledged_at IS NULL
                ORDER BY server_time, receipt_id
                LIMIT 1
                """.formatted(RESULT_COLUMNS), this::mapProcessed,
                userId, expeditionId);
        return resolutions.stream().findFirst();
    }

    @Override
    public void saveProcessed(
            EventIdempotencyScope scope,
            ProcessedEventResolution processed
    ) {
        EventResolutionResult result = processed.result();
        EventMaterialRewardResult material = result.material();
        long journeyNumber = currentJourneyNumber(
                scope.userId(),
                result.expeditionId()
        );
        jdbcTemplate.update("""
                INSERT INTO processed_event_resolution (
                    receipt_id,
                    user_id,
                    expedition_id,
                    event_id,
                    idempotency_key,
                    request_fingerprint,
                    content_version,
                    expedition_status,
                    expedition_version,
                    journey_number,
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
                    material_item_id,
                    material_item_name,
                    material_item_description,
                    material_quantity_gained,
                    material_quantity_after,
                    material_version,
                    handoff_required,
                    next_node_id,
                    next_node_name,
                    server_time,
                    created_at
                )
                VALUES (
                    ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
                    ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
                    ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
                    ?, ?, ?, ?, ?, ?, ?, ?, ?, now()
                )
                """,
                result.receiptId(),
                scope.userId(),
                result.expeditionId(),
                scope.eventId(),
                scope.idempotencyKey(),
                processed.requestFingerprint(),
                result.contentVersion(),
                result.expeditionStatus().name(),
                result.expeditionVersion(),
                journeyNumber,
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
                material == null ? null : material.itemId(),
                material == null ? null : material.name(),
                material == null ? null : material.description(),
                material == null ? null : material.quantityGained(),
                material == null ? null : material.quantityAfter(),
                material == null ? null : material.version(),
                result.handoffRequired(),
                result.nextNode() == null ? null : result.nextNode().nodeId(),
                result.nextNode() == null ? null : result.nextNode().name(),
                Timestamp.from(result.serverTime())
        );
    }

    private long currentJourneyNumber(String userId, String expeditionId) {
        Long journeyNumber = jdbcTemplate.queryForObject("""
                SELECT COALESCE((
                    SELECT journey_number
                    FROM expedition_journey_cycle
                    WHERE user_id = ?
                      AND expedition_id = ?
                ), 1)
                """, Long.class, userId, expeditionId);
        if (journeyNumber == null) {
            throw new IllegalStateException("Номер похода не найден");
        }
        return journeyNumber;
    }

    @Override
    public Optional<EventResultAcknowledgementResult> acknowledgeResult(
            String userId,
            UUID receiptId,
            Supplier<Instant> serverTimeSupplier
    ) {
        accountDeletionRegistry.requireActive(userId);
        Instant serverTime = serverTimeSupplier.get();
        List<EventResultAcknowledgementResult> acknowledged = jdbcTemplate.query("""
                UPDATE processed_event_resolution
                SET acknowledged_at = GREATEST(server_time, ?)
                WHERE user_id = ?
                  AND receipt_id = ?
                  AND acknowledged_at IS NULL
                RETURNING receipt_id, event_id, acknowledged_at
                """, this::mapAcknowledgement,
                Timestamp.from(serverTime), userId, receiptId);
        if (!acknowledged.isEmpty()) {
            return acknowledged.stream().findFirst();
        }

        List<EventResultAcknowledgementResult> existing = jdbcTemplate.query("""
                SELECT receipt_id, event_id, acknowledged_at
                FROM processed_event_resolution
                WHERE user_id = ?
                  AND receipt_id = ?
                  AND acknowledged_at IS NOT NULL
                """, this::mapAcknowledgement, userId, receiptId);
        return existing.stream().findFirst();
    }

    private EventResultAcknowledgementResult mapAcknowledgement(
            ResultSet resultSet,
            int rowNumber
    ) throws SQLException {
        Instant acknowledgedAt =
                resultSet.getTimestamp("acknowledged_at").toInstant();
        return new EventResultAcknowledgementResult(
                resultSet.getObject("receipt_id", UUID.class),
                resultSet.getString("event_id"),
                acknowledgedAt,
                acknowledgedAt
        );
    }

    private ProcessedEventResolution mapProcessed(
            ResultSet resultSet,
            int rowNumber
    ) throws SQLException {
        String nextNodeId = resultSet.getString("next_node_id");
        return new ProcessedEventResolution(
                resultSet.getString("request_fingerprint"),
                new EventResolutionResult(
                        resultSet.getObject("receipt_id", UUID.class),
                        resultSet.getString("content_version"),
                        resultSet.getString("expedition_id"),
                        ExpeditionProgressStatus.valueOf(
                                resultSet.getString("expedition_status")
                        ),
                        resultSet.getLong("expedition_version"),
                        resultSet.getString("event_id"),
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
                        readMaterial(resultSet),
                        resultSet.getBoolean("handoff_required"),
                        nextNodeId == null ? null : new EventNextNodeResult(
                                nextNodeId,
                                resultSet.getString("next_node_name")
                        ),
                        resultSet.getTimestamp("server_time").toInstant()
                )
        );
    }

    private static EventMaterialRewardResult readMaterial(ResultSet resultSet)
            throws SQLException {
        String itemId = resultSet.getString("material_item_id");
        if (itemId == null) {
            return null;
        }
        return new EventMaterialRewardResult(
                itemId,
                resultSet.getString("material_item_name"),
                resultSet.getString("material_item_description"),
                resultSet.getLong("material_quantity_gained"),
                resultSet.getLong("material_quantity_after"),
                resultSet.getLong("material_version")
        );
    }
}
