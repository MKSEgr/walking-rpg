package com.walkingrpg.backend.home.infrastructure;

import java.sql.Timestamp;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import com.walkingrpg.backend.expedition.domain.ProcessedEventResolution;
import com.walkingrpg.backend.expedition.infrastructure.EventResolutionRepository;
import com.walkingrpg.backend.home.domain.HomeRuntimeState;
import com.walkingrpg.backend.home.domain.InventoryRuntimeItem;
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
