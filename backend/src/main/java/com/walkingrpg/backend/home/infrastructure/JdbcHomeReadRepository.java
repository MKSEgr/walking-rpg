package com.walkingrpg.backend.home.infrastructure;

import java.sql.Timestamp;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

import com.walkingrpg.backend.home.domain.HomeRuntimeState;
import com.walkingrpg.backend.home.domain.InventoryRuntimeItem;
import com.walkingrpg.backend.progression.application.StarterProgressionContent;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class JdbcHomeReadRepository implements HomeReadRepository {

    private final JdbcTemplate jdbcTemplate;
    private final StarterProgressionContent progressionContent;

    public JdbcHomeReadRepository(
            JdbcTemplate jdbcTemplate,
            StarterProgressionContent progressionContent
    ) {
        this.jdbcTemplate = jdbcTemplate;
        this.progressionContent = progressionContent;
    }

    @Override
    public HomeRuntimeState findState(
            String userId,
            LocalDate localDate,
            String expeditionId
    ) {
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
                       expedition.current_node_id,
                       expedition.unlocked_event_id,
                       (pilot.user_id IS NOT NULL) AS pilot_progress_present,
                       COALESCE(pilot.level, 0) AS pilot_level,
                       COALESCE(pilot.current_experience, 0) AS pilot_current_experience,
                       COALESCE(pilot.next_level_experience, 0) AS pilot_next_level_experience,
                       (pet.user_id IS NOT NULL) AS pet_progress_present,
                       COALESCE(pet.level, 0) AS pet_level,
                       COALESCE(pet.bond, 0) AS pet_bond,
                       resolution.choice_id AS resolved_choice_id,
                       resolution.choice_title AS resolved_choice_title,
                       resolution.outcome_title,
                       resolution.outcome_summary,
                       resolution.material_item_id,
                       resolution.material_item_name,
                       resolution.material_item_description,
                       resolution.material_quantity_gained,
                       resolution.material_quantity_after,
                       resolution.material_version
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
                LEFT JOIN pilot_progress pilot
                  ON pilot.user_id = ?
                 AND pilot.pilot_id = ?
                LEFT JOIN pet_progress pet
                  ON pet.user_id = ?
                 AND pet.pet_id = ?
                LEFT JOIN processed_event_resolution resolution
                  ON resolution.user_id = ?
                 AND resolution.expedition_id = ?
                 AND resolution.event_id = expedition.unlocked_event_id
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
                    resultSet.getString("current_node_id"),
                    resultSet.getString("unlocked_event_id"),
                    resultSet.getBoolean("pilot_progress_present"),
                    resultSet.getInt("pilot_level"),
                    resultSet.getInt("pilot_current_experience"),
                    resultSet.getInt("pilot_next_level_experience"),
                    resultSet.getBoolean("pet_progress_present"),
                    resultSet.getInt("pet_level"),
                    resultSet.getInt("pet_bond"),
                    resultSet.getString("resolved_choice_id"),
                    resultSet.getString("resolved_choice_title"),
                    resultSet.getString("outcome_title"),
                    resultSet.getString("outcome_summary"),
                    resultSet.getString("material_item_id"),
                    resultSet.getString("material_item_name"),
                    resultSet.getString("material_item_description"),
                    resultSet.getObject("material_quantity_gained", Long.class),
                    resultSet.getObject("material_quantity_after", Long.class),
                    resultSet.getObject("material_version", Long.class),
                    List.of()
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
                progressionContent.pet().petId(),
                userId,
                expeditionId
        );

        if (state == null) {
            throw new IllegalStateException("Home read-model query не вернул строку");
        }
        return state.withInventory(findInventory(userId));
    }

    private List<InventoryRuntimeItem> findInventory(String userId) {
        return jdbcTemplate.query("""
                SELECT item_id, quantity, version
                FROM inventory_stack
                WHERE user_id = ?
                  AND quantity > 0
                ORDER BY item_id
                """, (resultSet, rowNumber) -> new InventoryRuntimeItem(
                resultSet.getString("item_id"),
                resultSet.getLong("quantity"),
                resultSet.getLong("version")
        ), userId);
    }
}
