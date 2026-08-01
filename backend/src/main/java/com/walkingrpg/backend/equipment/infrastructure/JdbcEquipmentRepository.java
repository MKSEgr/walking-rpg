package com.walkingrpg.backend.equipment.infrastructure;

import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import com.walkingrpg.backend.account.application.AccountDeletionRegistry;
import com.walkingrpg.backend.equipment.domain.EquipmentAction;
import com.walkingrpg.backend.equipment.domain.EquipmentIdempotencyScope;
import com.walkingrpg.backend.equipment.domain.EquipmentResult;
import com.walkingrpg.backend.equipment.domain.EquipmentSlotDefinition;
import com.walkingrpg.backend.equipment.domain.EquipmentSlotState;
import com.walkingrpg.backend.equipment.domain.EquippedItemResult;
import com.walkingrpg.backend.equipment.domain.ProcessedEquipmentCommand;
import com.walkingrpg.backend.equipment.domain.UniqueInventoryItemReference;
import com.walkingrpg.backend.inventory.domain.InventoryItemDefinition;
import com.walkingrpg.backend.operations.JdbcStatementTimeouts;
import org.springframework.jdbc.core.ConnectionCallback;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class JdbcEquipmentRepository implements EquipmentRepository {

    private static final String LOCK_SQL = """
            SELECT pg_advisory_xact_lock(hashtextextended(?, 41))
            """;

    private final JdbcTemplate jdbcTemplate;
    private final AccountDeletionRegistry accountDeletionRegistry;

    public JdbcEquipmentRepository(
            JdbcTemplate jdbcTemplate,
            AccountDeletionRegistry accountDeletionRegistry
    ) {
        this.jdbcTemplate = jdbcTemplate;
        this.accountDeletionRegistry = accountDeletionRegistry;
    }

    @Override
    public void acquireLock(String userId) {
        accountDeletionRegistry.requireActive(userId);
        jdbcTemplate.execute((ConnectionCallback<Void>) connection -> {
            try (PreparedStatement statement = connection.prepareStatement(LOCK_SQL)) {
                JdbcStatementTimeouts.apply(jdbcTemplate, statement);
                statement.setString(1, userId);
                statement.execute();
            }
            return null;
        });
    }

    @Override
    public Optional<ProcessedEquipmentCommand> findProcessed(
            EquipmentIdempotencyScope scope
    ) {
        List<ProcessedRow> rows = jdbcTemplate.query("""
                SELECT request_fingerprint,
                       content_version,
                       action,
                       changed,
                       slot_name,
                       slot_description,
                       equipment_version,
                       item_instance_id,
                       item_id,
                       item_name,
                       item_description,
                       equipped_at,
                       server_time
                FROM processed_equipment_command
                WHERE user_id = ?
                  AND slot_id = ?
                  AND idempotency_key = ?
                """, this::mapProcessed,
                scope.userId(), scope.slotId(), scope.idempotencyKey());
        if (rows.isEmpty()) {
            return Optional.empty();
        }
        ProcessedRow row = rows.getFirst();
        EquippedItemResult item = row.itemInstanceId() == null
                ? null
                : new EquippedItemResult(
                        row.itemInstanceId(),
                        row.itemId(),
                        row.itemName(),
                        row.itemDescription(),
                        row.equippedAt()
                );
        return Optional.of(new ProcessedEquipmentCommand(
                row.requestFingerprint(),
                new EquipmentResult(
                        row.contentVersion(),
                        scope.slotId(),
                        row.slotName(),
                        row.slotDescription(),
                        row.action(),
                        row.changed(),
                        row.version(),
                        item,
                        row.serverTime()
                )
        ));
    }

    @Override
    public Optional<UniqueInventoryItemReference> lockOwnedUniqueItem(
            String userId,
            UUID itemInstanceId
    ) {
        List<UniqueInventoryItemReference> rows = jdbcTemplate.query("""
                SELECT item_instance_id, item_id
                FROM unique_inventory_item
                WHERE user_id = ?
                  AND item_instance_id = ?
                FOR SHARE
                """, (resultSet, rowNumber) -> new UniqueInventoryItemReference(
                resultSet.getObject("item_instance_id", UUID.class),
                resultSet.getString("item_id")
        ), userId, itemInstanceId);
        return rows.stream().findFirst();
    }

    @Override
    public EquipmentResult apply(
            EquipmentIdempotencyScope scope,
            String requestFingerprint,
            String contentVersion,
            EquipmentAction action,
            EquipmentSlotDefinition slot,
            UniqueInventoryItemReference itemReference,
            InventoryItemDefinition itemDefinition,
            Instant serverTime
    ) {
        ensureUser(scope.userId(), serverTime);
        EquipmentSlotState current = lockSlot(scope.userId(), scope.slotId())
                .orElseGet(() -> EquipmentSlotState.empty(scope.slotId()));
        EquipmentSlotState updated;
        boolean changed;
        EquippedItemResult equippedItem;
        if (action == EquipmentAction.EQUIP) {
            changed = !itemReference.itemInstanceId().equals(
                    current.itemInstanceId()
            );
            updated = changed
                    ? equip(scope, itemReference, serverTime)
                    : current;
            equippedItem = new EquippedItemResult(
                    updated.itemInstanceId(),
                    itemDefinition.itemId(),
                    itemDefinition.name(),
                    itemDefinition.description(),
                    updated.equippedAt()
            );
        } else {
            changed = current.isEquipped();
            updated = changed ? unequip(scope, serverTime) : current;
            equippedItem = null;
        }
        EquipmentResult result = new EquipmentResult(
                contentVersion,
                slot.slotId(),
                slot.name(),
                slot.description(),
                action,
                changed,
                updated.version(),
                equippedItem,
                serverTime
        );
        saveProcessed(scope, requestFingerprint, result);
        return result;
    }

    private void ensureUser(String userId, Instant observedAt) {
        Timestamp timestamp = Timestamp.from(observedAt);
        jdbcTemplate.update("""
                INSERT INTO app_user (user_id, created_at, last_seen_at)
                VALUES (?, ?, ?)
                ON CONFLICT (user_id) DO UPDATE
                SET last_seen_at = GREATEST(
                    app_user.last_seen_at,
                    EXCLUDED.last_seen_at
                )
                """, userId, timestamp, timestamp);
    }

    @Override
    public List<EquipmentSlotState> findAll(String userId) {
        return jdbcTemplate.query("""
                SELECT state.slot_id,
                       state.version,
                       state.item_instance_id,
                       item.item_id,
                       state.equipped_at
                FROM equipment_slot_state state
                LEFT JOIN unique_inventory_item item
                  ON item.user_id = state.user_id
                 AND item.item_instance_id = state.item_instance_id
                WHERE state.user_id = ?
                ORDER BY state.slot_id
                """, this::mapSlotState, userId);
    }

    @Override
    public boolean isEquipped(String userId, String slotId, String itemId) {
        Boolean equipped = jdbcTemplate.queryForObject("""
                SELECT EXISTS (
                    SELECT 1
                    FROM equipment_slot_state state
                    JOIN unique_inventory_item item
                      ON item.user_id = state.user_id
                     AND item.item_instance_id = state.item_instance_id
                    WHERE state.user_id = ?
                      AND state.slot_id = ?
                      AND item.item_id = ?
                )
                """, Boolean.class, userId, slotId, itemId);
        return Boolean.TRUE.equals(equipped);
    }

    private Optional<EquipmentSlotState> lockSlot(String userId, String slotId) {
        List<EquipmentSlotState> rows = jdbcTemplate.query("""
                SELECT state.slot_id,
                       state.version,
                       state.item_instance_id,
                       item.item_id,
                       state.equipped_at
                FROM equipment_slot_state state
                LEFT JOIN unique_inventory_item item
                  ON item.user_id = state.user_id
                 AND item.item_instance_id = state.item_instance_id
                WHERE state.user_id = ?
                  AND state.slot_id = ?
                FOR UPDATE OF state
                """, this::mapSlotState, userId, slotId);
        return rows.stream().findFirst();
    }

    private EquipmentSlotState equip(
            EquipmentIdempotencyScope scope,
            UniqueInventoryItemReference item,
            Instant serverTime
    ) {
        List<EquipmentSlotState> rows = jdbcTemplate.query("""
                INSERT INTO equipment_slot_state (
                    user_id,
                    slot_id,
                    item_instance_id,
                    version,
                    equipped_at,
                    updated_at
                ) VALUES (?, ?, ?, 1, ?, ?)
                ON CONFLICT (user_id, slot_id) DO UPDATE
                SET item_instance_id = EXCLUDED.item_instance_id,
                    version = equipment_slot_state.version + 1,
                    equipped_at = EXCLUDED.equipped_at,
                    updated_at = EXCLUDED.updated_at
                RETURNING slot_id, version, item_instance_id, equipped_at
                """, (resultSet, rowNumber) -> new EquipmentSlotState(
                resultSet.getString("slot_id"),
                resultSet.getLong("version"),
                resultSet.getObject("item_instance_id", UUID.class),
                item.itemId(),
                resultSet.getTimestamp("equipped_at").toInstant()
        ),
                scope.userId(),
                scope.slotId(),
                item.itemInstanceId(),
                Timestamp.from(serverTime),
                Timestamp.from(serverTime));
        return rows.getFirst();
    }

    private EquipmentSlotState unequip(
            EquipmentIdempotencyScope scope,
            Instant serverTime
    ) {
        List<EquipmentSlotState> rows = jdbcTemplate.query("""
                UPDATE equipment_slot_state
                SET item_instance_id = NULL,
                    version = version + 1,
                    equipped_at = NULL,
                    updated_at = ?
                WHERE user_id = ?
                  AND slot_id = ?
                RETURNING slot_id, version
                """, (resultSet, rowNumber) -> new EquipmentSlotState(
                resultSet.getString("slot_id"),
                resultSet.getLong("version"),
                null,
                null,
                null
        ), Timestamp.from(serverTime), scope.userId(), scope.slotId());
        return rows.stream().findFirst().orElseThrow(() ->
                new IllegalStateException("Equipment slot исчез после блокировки")
        );
    }

    private void saveProcessed(
            EquipmentIdempotencyScope scope,
            String requestFingerprint,
            EquipmentResult result
    ) {
        EquippedItemResult item = result.equippedItem();
        jdbcTemplate.update("""
                INSERT INTO processed_equipment_command (
                    user_id,
                    slot_id,
                    idempotency_key,
                    request_fingerprint,
                    content_version,
                    action,
                    changed,
                    slot_name,
                    slot_description,
                    equipment_version,
                    item_instance_id,
                    item_id,
                    item_name,
                    item_description,
                    equipped_at,
                    server_time,
                    created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, now())
                """,
                scope.userId(),
                scope.slotId(),
                scope.idempotencyKey(),
                requestFingerprint,
                result.contentVersion(),
                result.action().name(),
                result.changed(),
                result.slotName(),
                result.slotDescription(),
                result.version(),
                item == null ? null : item.itemInstanceId(),
                item == null ? null : item.itemId(),
                item == null ? null : item.name(),
                item == null ? null : item.description(),
                item == null ? null : Timestamp.from(item.equippedAt()),
                Timestamp.from(result.serverTime())
        );
    }

    private EquipmentSlotState mapSlotState(
            ResultSet resultSet,
            int rowNumber
    ) throws SQLException {
        UUID itemInstanceId = resultSet.getObject("item_instance_id", UUID.class);
        Timestamp equippedAt = resultSet.getTimestamp("equipped_at");
        return new EquipmentSlotState(
                resultSet.getString("slot_id"),
                resultSet.getLong("version"),
                itemInstanceId,
                itemInstanceId == null ? null : resultSet.getString("item_id"),
                equippedAt == null ? null : equippedAt.toInstant()
        );
    }

    private ProcessedRow mapProcessed(
            ResultSet resultSet,
            int rowNumber
    ) throws SQLException {
        UUID itemInstanceId = resultSet.getObject("item_instance_id", UUID.class);
        Timestamp equippedAt = resultSet.getTimestamp("equipped_at");
        return new ProcessedRow(
                resultSet.getString("request_fingerprint"),
                resultSet.getString("content_version"),
                EquipmentAction.valueOf(resultSet.getString("action")),
                resultSet.getBoolean("changed"),
                resultSet.getString("slot_name"),
                resultSet.getString("slot_description"),
                resultSet.getLong("equipment_version"),
                itemInstanceId,
                resultSet.getString("item_id"),
                resultSet.getString("item_name"),
                resultSet.getString("item_description"),
                equippedAt == null ? null : equippedAt.toInstant(),
                resultSet.getTimestamp("server_time").toInstant()
        );
    }

    private record ProcessedRow(
            String requestFingerprint,
            String contentVersion,
            EquipmentAction action,
            boolean changed,
            String slotName,
            String slotDescription,
            long version,
            UUID itemInstanceId,
            String itemId,
            String itemName,
            String itemDescription,
            Instant equippedAt,
            Instant serverTime
    ) {
    }
}
