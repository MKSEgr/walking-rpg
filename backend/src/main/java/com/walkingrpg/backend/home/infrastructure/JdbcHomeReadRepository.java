package com.walkingrpg.backend.home.infrastructure;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import com.walkingrpg.backend.expedition.domain.ProcessedEventResolution;
import com.walkingrpg.backend.expedition.infrastructure.EventResolutionRepository;
import com.walkingrpg.backend.home.domain.ExpeditionJourneyChronicleTotals;
import com.walkingrpg.backend.home.domain.ExpeditionJourneyEvent;
import com.walkingrpg.backend.home.domain.ExpeditionJourneyFinaleOutcomeSnapshot;
import com.walkingrpg.backend.home.domain.ExpeditionJourneyHistory;
import com.walkingrpg.backend.home.domain.HomeRuntimeState;
import com.walkingrpg.backend.home.domain.InventoryRuntimeItem;
import com.walkingrpg.backend.home.domain.MaterialRewardPreviewSnapshot;
import com.walkingrpg.backend.home.domain.PetBondRewardSnapshot;
import com.walkingrpg.backend.progression.application.ActivePetProvider;
import com.walkingrpg.backend.progression.application.ActivePetSelection;
import com.walkingrpg.backend.progression.application.StarterProgressionContent;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class JdbcHomeReadRepository implements HomeReadRepository {

    private final JdbcTemplate jdbcTemplate;
    private final StarterProgressionContent progressionContent;
    private final ActivePetProvider activePetProvider;
    private final EventResolutionRepository eventResolutionRepository;

    public JdbcHomeReadRepository(
            JdbcTemplate jdbcTemplate,
            StarterProgressionContent progressionContent,
            ActivePetProvider activePetProvider,
            EventResolutionRepository eventResolutionRepository
    ) {
        this.jdbcTemplate = jdbcTemplate;
        this.progressionContent = progressionContent;
        this.activePetProvider = activePetProvider;
        this.eventResolutionRepository = eventResolutionRepository;
    }

    @Override
    public Optional<ProcessedEventResolution> findPendingEventResult(
            String userId,
            String expeditionId
    ) {
        return eventResolutionRepository.findPendingResult(userId, expeditionId);
    }

    @Override
    public List<ExpeditionJourneyEvent> findJourneyEvents(
            String userId,
            String expeditionId,
            long journeyNumber
    ) {
        return jdbcTemplate.query("""
                SELECT event_id,
                       event_title,
                       choice_id,
                       choice_title,
                       outcome_title,
                       outcome_summary,
                       pilot_experience_gained,
                       pet_id,
                       pet_name,
                       pet_bond_gained,
                       material_item_id,
                       material_item_name,
                       material_quantity_gained,
                       server_time
                FROM processed_event_resolution
                WHERE user_id = ?
                  AND expedition_id = ?
                  AND journey_number = ?
                ORDER BY expedition_version, receipt_id
                """, (resultSet, rowNumber) -> journeyEvent(resultSet),
                userId, expeditionId, journeyNumber);
    }

    @Override
    public List<ExpeditionJourneyHistory> findRecentCompletedJourneys(
            String userId,
            String expeditionId,
            long currentJourneyNumber,
            int limit
    ) {
        return jdbcTemplate.query("""
                WITH recent_completed_journey AS (
                    SELECT DISTINCT
                           journey_number - 1 AS completed_journey_number
                    FROM processed_expedition_journey_start
                    WHERE user_id = ?
                      AND expedition_id = ?
                      AND journey_number <= ?
                    ORDER BY completed_journey_number DESC
                    LIMIT ?
                )
                SELECT resolution.journey_number,
                       resolution.event_id,
                       resolution.event_title,
                       resolution.choice_id,
                       resolution.choice_title,
                       resolution.outcome_title,
                       resolution.outcome_summary,
                       resolution.pilot_experience_gained,
                       resolution.pet_id,
                       resolution.pet_name,
                       resolution.pet_bond_gained,
                       resolution.material_item_id,
                       resolution.material_item_name,
                       resolution.material_quantity_gained,
                       resolution.server_time
                FROM recent_completed_journey completed
                JOIN processed_event_resolution resolution
                 ON resolution.user_id = ?
                 AND resolution.expedition_id = ?
                 AND resolution.journey_number =
                         completed.completed_journey_number
                ORDER BY resolution.journey_number DESC,
                         resolution.expedition_version,
                         resolution.receipt_id
                """, resultSet -> {
            List<ExpeditionJourneyHistory> histories = new ArrayList<>();
            List<ExpeditionJourneyEvent> events = null;
            long journeyNumber = -1;
            while (resultSet.next()) {
                long rowJourneyNumber = resultSet.getLong("journey_number");
                if (rowJourneyNumber != journeyNumber) {
                    if (events != null) {
                        histories.add(new ExpeditionJourneyHistory(
                                journeyNumber,
                                events
                        ));
                    }
                    journeyNumber = rowJourneyNumber;
                    events = new ArrayList<>();
                }
                events.add(journeyEvent(resultSet));
            }
            if (events != null) {
                histories.add(new ExpeditionJourneyHistory(
                        journeyNumber,
                        events
                ));
            }
            return List.copyOf(histories);
        }, userId, expeditionId, currentJourneyNumber, limit,
                userId, expeditionId);
    }

    @Override
    public ExpeditionJourneyChronicleTotals findCompletedJourneyChronicle(
            String userId,
            String expeditionId,
            long currentJourneyNumber
    ) {
        ExpeditionJourneyChronicleTotals totals = jdbcTemplate.queryForObject("""
                WITH completed_journey AS (
                    SELECT DISTINCT
                           journey_number - 1 AS completed_journey_number
                    FROM processed_expedition_journey_start
                    WHERE user_id = ?
                      AND expedition_id = ?
                      AND journey_number <= ?
                )
                SELECT COUNT(DISTINCT completed.completed_journey_number)
                           AS completed_journey_count,
                       COUNT(resolution.event_id) AS decision_count,
                       COALESCE(SUM(
                           resolution.pilot_experience_gained
                       ), 0) AS pilot_experience_gained,
                       COALESCE(SUM(
                           resolution.pet_bond_gained
                       ), 0) AS pet_bond_gained
                FROM completed_journey completed
                LEFT JOIN processed_event_resolution resolution
                  ON resolution.user_id = ?
                 AND resolution.expedition_id = ?
                 AND resolution.journey_number =
                         completed.completed_journey_number
                """, (resultSet, rowNumber) ->
                        new ExpeditionJourneyChronicleTotals(
                                resultSet.getLong(
                                        "completed_journey_count"
                                ),
                                resultSet.getLong("decision_count"),
                                resultSet.getLong(
                                        "pilot_experience_gained"
                                ),
                                resultSet.getLong("pet_bond_gained"),
                                List.of(),
                                List.of(),
                                List.of()
                        ),
                userId,
                expeditionId,
                currentJourneyNumber,
                userId,
                expeditionId
        );
        List<PetBondRewardSnapshot> petBondRewards = jdbcTemplate.query("""
                WITH completed_journey AS (
                    SELECT DISTINCT
                           journey_number - 1 AS completed_journey_number
                    FROM processed_expedition_journey_start
                    WHERE user_id = ?
                      AND expedition_id = ?
                      AND journey_number <= ?
                ),
                eligible_resolution AS (
                    SELECT resolution.journey_number,
                           resolution.expedition_version,
                           resolution.receipt_id,
                           resolution.pet_id,
                           resolution.pet_name,
                           resolution.pet_bond_gained
                    FROM completed_journey completed
                    JOIN processed_event_resolution resolution
                      ON resolution.user_id = ?
                     AND resolution.expedition_id = ?
                     AND resolution.journey_number =
                             completed.completed_journey_number
                    WHERE resolution.pet_bond_gained > 0
                ),
                ordered_pet AS (
                    SELECT pet_id,
                           pet_name,
                           SUM(pet_bond_gained) OVER (
                               PARTITION BY pet_id, pet_name
                           ) AS bond_gained,
                           ROW_NUMBER() OVER (
                               PARTITION BY pet_id, pet_name
                               ORDER BY journey_number,
                                        expedition_version,
                                        receipt_id
                           ) AS identity_row,
                           journey_number,
                           expedition_version,
                           receipt_id
                    FROM eligible_resolution
                )
                SELECT pet_id,
                       pet_name,
                       bond_gained
                FROM ordered_pet
                WHERE identity_row = 1
                ORDER BY journey_number,
                         expedition_version,
                         receipt_id
                """, (resultSet, rowNumber) -> new PetBondRewardSnapshot(
                        resultSet.getString("pet_id"),
                        resultSet.getString("pet_name"),
                        resultSet.getLong("bond_gained")
                ), userId, expeditionId, currentJourneyNumber,
                userId, expeditionId);
        List<MaterialRewardPreviewSnapshot> materials = jdbcTemplate.query("""
                WITH completed_journey AS (
                    SELECT DISTINCT
                           journey_number - 1 AS completed_journey_number
                    FROM processed_expedition_journey_start
                    WHERE user_id = ?
                      AND expedition_id = ?
                      AND journey_number <= ?
                ),
                eligible_resolution AS (
                    SELECT resolution.journey_number,
                           resolution.expedition_version,
                           resolution.receipt_id,
                           resolution.material_item_id,
                           resolution.material_item_name,
                           resolution.material_quantity_gained
                    FROM completed_journey completed
                    JOIN processed_event_resolution resolution
                      ON resolution.user_id = ?
                     AND resolution.expedition_id = ?
                     AND resolution.journey_number =
                             completed.completed_journey_number
                    WHERE resolution.material_quantity_gained > 0
                ),
                ordered_material AS (
                    SELECT material_item_id,
                           material_item_name,
                           SUM(material_quantity_gained) OVER (
                               PARTITION BY material_item_id,
                                            material_item_name
                           ) AS quantity,
                           ROW_NUMBER() OVER (
                               PARTITION BY material_item_id,
                                            material_item_name
                               ORDER BY journey_number,
                                        expedition_version,
                                        receipt_id
                           ) AS identity_row,
                           journey_number,
                           expedition_version,
                           receipt_id
                    FROM eligible_resolution
                )
                SELECT material_item_id,
                       material_item_name,
                       quantity
                FROM ordered_material
                WHERE identity_row = 1
                ORDER BY journey_number,
                         expedition_version,
                         receipt_id
                """, (resultSet, rowNumber) ->
                        new MaterialRewardPreviewSnapshot(
                                resultSet.getString("material_item_id"),
                                resultSet.getString("material_item_name"),
                                resultSet.getLong("quantity")
                ), userId, expeditionId, currentJourneyNumber,
                userId, expeditionId);
        List<ExpeditionJourneyFinaleOutcomeSnapshot> finaleOutcomes =
                jdbcTemplate.query("""
                WITH completed_journey AS (
                    SELECT DISTINCT
                           journey_number - 1 AS completed_journey_number
                    FROM processed_expedition_journey_start
                    WHERE user_id = ?
                      AND expedition_id = ?
                      AND journey_number <= ?
                ),
                ranked_resolution AS (
                    SELECT resolution.journey_number,
                           resolution.expedition_version,
                           resolution.receipt_id,
                           resolution.event_id,
                           resolution.event_title,
                           resolution.choice_id,
                           resolution.choice_title,
                           resolution.outcome_title,
                           ROW_NUMBER() OVER (
                               PARTITION BY resolution.journey_number
                               ORDER BY resolution.expedition_version DESC,
                                        resolution.receipt_id DESC
                           ) AS journey_row
                    FROM completed_journey completed
                    JOIN processed_event_resolution resolution
                      ON resolution.user_id = ?
                     AND resolution.expedition_id = ?
                     AND resolution.journey_number =
                             completed.completed_journey_number
                ),
                final_resolution AS (
                    SELECT journey_number,
                           expedition_version,
                           receipt_id,
                           event_id,
                           event_title,
                           choice_id,
                           choice_title,
                           outcome_title
                    FROM ranked_resolution
                    WHERE journey_row = 1
                ),
                ordered_finale AS (
                    SELECT event_id,
                           event_title,
                           choice_id,
                           choice_title,
                           outcome_title,
                           COUNT(*) OVER (
                               PARTITION BY event_id,
                                            event_title,
                                            choice_id,
                                            choice_title,
                                            outcome_title
                           ) AS journey_count,
                           ROW_NUMBER() OVER (
                               PARTITION BY event_id,
                                            event_title,
                                            choice_id,
                                            choice_title,
                                            outcome_title
                               ORDER BY journey_number,
                                        expedition_version,
                                        receipt_id
                           ) AS identity_row,
                           journey_number,
                           expedition_version,
                           receipt_id
                    FROM final_resolution
                )
                SELECT event_id,
                       event_title,
                       choice_id,
                       choice_title,
                       outcome_title,
                       journey_count
                FROM ordered_finale
                WHERE identity_row = 1
                ORDER BY journey_number,
                         expedition_version,
                         receipt_id
                """, (resultSet, rowNumber) ->
                        new ExpeditionJourneyFinaleOutcomeSnapshot(
                                resultSet.getString("event_id"),
                                resultSet.getString("event_title"),
                                resultSet.getString("choice_id"),
                                resultSet.getString("choice_title"),
                                resultSet.getString("outcome_title"),
                                resultSet.getLong("journey_count")
                        ), userId, expeditionId, currentJourneyNumber,
                userId, expeditionId);
        return new ExpeditionJourneyChronicleTotals(
                totals.completedJourneyCount(),
                totals.decisionCount(),
                totals.pilotExperienceGained(),
                totals.petBondGained(),
                petBondRewards,
                materials,
                finaleOutcomes
        );
    }

    private ExpeditionJourneyEvent journeyEvent(
            ResultSet resultSet
    ) throws SQLException {
        Long materialQuantity = resultSet.getObject(
                "material_quantity_gained",
                Long.class
        );
        MaterialRewardPreviewSnapshot material = materialQuantity == null
                ? null
                : new MaterialRewardPreviewSnapshot(
                        resultSet.getString("material_item_id"),
                        resultSet.getString("material_item_name"),
                        materialQuantity
                );
        return new ExpeditionJourneyEvent(
                resultSet.getString("event_id"),
                resultSet.getString("event_title"),
                resultSet.getString("choice_id"),
                resultSet.getString("choice_title"),
                resultSet.getString("outcome_title"),
                resultSet.getString("outcome_summary"),
                resultSet.getInt("pilot_experience_gained"),
                resultSet.getString("pet_id"),
                resultSet.getString("pet_name"),
                resultSet.getInt("pet_bond_gained"),
                material,
                resultSet.getTimestamp("server_time").toInstant()
        );
    }

    @Override
    public HomeRuntimeState findState(
            String userId,
            LocalDate localDate,
            String expeditionId
    ) {
        ActivePetSelection activePet = activePetProvider.activePetFor(userId);
        String activePetId = activePet.petId();
        HomeRuntimeState state = jdbcTemplate.queryForObject("""
                SELECT COALESCE(activity.accepted_total, 0) AS daily_steps,
                       COALESCE(activity.state_version, 0) AS activity_state_version,
                       activity.time_zone,
                       activity.updated_at AS last_activity_sync_at,
                       COALESCE(wallet.balance, 0) AS available_energy,
                       COALESCE(wallet.version, 0) AS economy_version,
                       COALESCE(expedition.progress_energy, 0) AS expedition_progress,
                       COALESCE(expedition.required_energy, 0) AS expedition_required_energy,
                       expedition.status AS expedition_status,
                       COALESCE(expedition.version, 0) AS expedition_version,
                       COALESCE(journey.journey_number, 1) AS expedition_journey_number,
                       expedition.current_node_id,
                       expedition.unlocked_event_id,
                       (pilot.user_id IS NOT NULL) AS pilot_progress_present,
                       COALESCE(pilot.level, 0) AS pilot_level,
                       COALESCE(pilot.current_experience, 0) AS pilot_current_experience,
                       COALESCE(pilot.next_level_experience, 0) AS pilot_next_level_experience,
                       COALESCE(pet.level, 0) AS pet_level,
                       COALESCE(pet.bond, 0) AS pet_bond
                FROM (VALUES (1)) AS anchor(value)
                LEFT JOIN activity_sync_state activity
                  ON activity.user_id = ?
                 AND activity.local_date = ?
                LEFT JOIN economy_wallet wallet
                  ON wallet.user_id = ?
                 AND wallet.currency_code = 'ENERGY'
                LEFT JOIN expedition_progress expedition
                  ON expedition.user_id = ?
                 AND expedition.expedition_id = ?
                LEFT JOIN expedition_journey_cycle journey
                  ON journey.user_id = expedition.user_id
                 AND journey.expedition_id = expedition.expedition_id
                LEFT JOIN pilot_progress pilot
                  ON pilot.user_id = ?
                 AND pilot.pilot_id = ?
                LEFT JOIN pet_progress pet
                  ON pet.user_id = ?
                 AND pet.pet_id = ?
                """, (resultSet, rowNumber) -> {
            Timestamp lastSync = resultSet.getTimestamp("last_activity_sync_at");
            Instant lastActivitySyncAt = lastSync == null ? null : lastSync.toInstant();

            return new HomeRuntimeState(
                    resultSet.getLong("daily_steps"),
                    resultSet.getLong("activity_state_version"),
                    resultSet.getString("time_zone"),
                    lastActivitySyncAt,
                    resultSet.getLong("available_energy"),
                    resultSet.getLong("economy_version"),
                    resultSet.getLong("expedition_progress"),
                    resultSet.getLong("expedition_required_energy"),
                    resultSet.getString("expedition_status"),
                    resultSet.getLong("expedition_version"),
                    resultSet.getLong("expedition_journey_number"),
                    resultSet.getString("current_node_id"),
                    resultSet.getString("unlocked_event_id"),
                    resultSet.getBoolean("pilot_progress_present"),
                    resultSet.getInt("pilot_level"),
                    resultSet.getInt("pilot_current_experience"),
                    resultSet.getInt("pilot_next_level_experience"),
                    activePetId,
                    true,
                    Math.max(resultSet.getInt("pet_level"), activePet.level()),
                    Math.max(resultSet.getInt("pet_bond"), activePet.bond()),
                    activePet.evolutionStage(),
                    null,
                    null,
                    null,
                    null,
                    null,
                    null,
                    null,
                    null,
                    null,
                    null,
                    List.<InventoryRuntimeItem>of()
            );
        },
                userId,
                localDate,
                userId,
                userId,
                expeditionId,
                userId,
                progressionContent.pilot().pilotId(),
                userId,
                activePetId
        );

        if (state == null) {
            throw new IllegalStateException("Home read-model query не вернул строку");
        }
        return state.withInventory(findInventory(userId));
    }

    private List<InventoryRuntimeItem> findInventory(String userId) {
        return jdbcTemplate.query("""
                SELECT item_id,
                       quantity,
                       version,
                       item_instance_id,
                       equipped_slot_id,
                       rarity
                FROM (
                    SELECT item_id,
                           quantity,
                           version,
                           NULL::uuid AS item_instance_id,
                           NULL::varchar AS equipped_slot_id,
                           NULL::varchar AS rarity
                    FROM inventory_stack
                    WHERE user_id = ?
                      AND quantity > 0
                    UNION ALL
                    SELECT item.item_id,
                           1 AS quantity,
                           item.version,
                           item.item_instance_id,
                           equipment.slot_id AS equipped_slot_id,
                           item.rarity
                    FROM unique_inventory_item item
                    LEFT JOIN equipment_slot_state equipment
                      ON equipment.user_id = item.user_id
                     AND equipment.item_instance_id = item.item_instance_id
                    WHERE item.user_id = ?
                ) inventory
                ORDER BY item_id
                """, (resultSet, rowNumber) -> new InventoryRuntimeItem(
                resultSet.getString("item_id"),
                resultSet.getLong("quantity"),
                resultSet.getLong("version"),
                resultSet.getObject("item_instance_id", java.util.UUID.class),
                resultSet.getString("equipped_slot_id"),
                resultSet.getString("rarity")
        ), userId, userId);
    }
}
