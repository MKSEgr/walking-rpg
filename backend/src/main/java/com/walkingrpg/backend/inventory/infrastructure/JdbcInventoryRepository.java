package com.walkingrpg.backend.inventory.infrastructure;

import java.sql.Timestamp;
import java.util.List;
import java.util.Optional;

import com.walkingrpg.backend.inventory.domain.InventoryLedgerConflictException;
import com.walkingrpg.backend.inventory.domain.InventoryReward;
import com.walkingrpg.backend.inventory.domain.InventoryStackSnapshot;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class JdbcInventoryRepository implements InventoryRepository {

    private final JdbcTemplate jdbcTemplate;

    public JdbcInventoryRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public InventoryStackSnapshot applyReward(InventoryReward reward) {
        ensureStack(reward);
        InventoryStackSnapshot current = lockStack(reward.userId(), reward.itemId());
        ExistingReward existing = findExistingReward(reward).orElse(null);
        if (existing != null) {
            if (!existing.itemId().equals(reward.itemId())
                    || existing.quantity() != reward.quantity()
                    || !existing.reasonCode().equals(reward.reasonCode())) {
                throw new InventoryLedgerConflictException(
                        "Источник inventory ledger уже использован для другой награды"
                );
            }
            return existing.snapshot();
        }

        InventoryStackSnapshot updated = addToStack(reward, current);
        appendLedger(reward, updated);
        return updated;
    }

    @Override
    public List<InventoryStackSnapshot> findAll(String userId) {
        return jdbcTemplate.query("""
                SELECT item_id, quantity, version
                FROM inventory_stack
                WHERE user_id = ?
                  AND quantity > 0
                ORDER BY item_id
                """, (resultSet, rowNumber) -> new InventoryStackSnapshot(
                resultSet.getString("item_id"),
                resultSet.getLong("quantity"),
                resultSet.getLong("version")
        ), userId);
    }

    private void ensureStack(InventoryReward reward) {
        Timestamp timestamp = Timestamp.from(reward.occurredAt());
        jdbcTemplate.update("""
                INSERT INTO inventory_stack (
                    user_id,
                    item_id,
                    quantity,
                    version,
                    created_at,
                    updated_at
                )
                VALUES (?, ?, 0, 0, ?, ?)
                ON CONFLICT (user_id, item_id) DO NOTHING
                """,
                reward.userId(),
                reward.itemId(),
                timestamp,
                timestamp
        );
    }

    private InventoryStackSnapshot lockStack(String userId, String itemId) {
        List<InventoryStackSnapshot> stacks = jdbcTemplate.query("""
                SELECT item_id, quantity, version
                FROM inventory_stack
                WHERE user_id = ?
                  AND item_id = ?
                FOR UPDATE
                """, (resultSet, rowNumber) -> new InventoryStackSnapshot(
                resultSet.getString("item_id"),
                resultSet.getLong("quantity"),
                resultSet.getLong("version")
        ), userId, itemId);
        return stacks.stream()
                .findFirst()
                .orElseThrow(() -> new IllegalStateException("Inventory stack не создан"));
    }

    private Optional<ExistingReward> findExistingReward(InventoryReward reward) {
        List<ExistingReward> rewards = jdbcTemplate.query("""
                SELECT item_id,
                       quantity_delta,
                       reason_code,
                       quantity_after,
                       inventory_version
                FROM inventory_ledger
                WHERE user_id = ?
                  AND source_type = ?
                  AND source_key = ?
                """, (resultSet, rowNumber) -> new ExistingReward(
                resultSet.getString("item_id"),
                resultSet.getLong("quantity_delta"),
                resultSet.getString("reason_code"),
                new InventoryStackSnapshot(
                        resultSet.getString("item_id"),
                        resultSet.getLong("quantity_after"),
                        resultSet.getLong("inventory_version")
                )
        ),
                reward.userId(),
                reward.sourceType(),
                reward.sourceKey()
        );
        return rewards.stream().findFirst();
    }

    private InventoryStackSnapshot addToStack(
            InventoryReward reward,
            InventoryStackSnapshot current
    ) {
        long expectedQuantity = Math.addExact(current.quantity(), reward.quantity());
        List<InventoryStackSnapshot> stacks = jdbcTemplate.query("""
                UPDATE inventory_stack
                SET quantity = quantity + ?,
                    version = version + 1,
                    updated_at = ?
                WHERE user_id = ?
                  AND item_id = ?
                RETURNING item_id, quantity, version
                """, (resultSet, rowNumber) -> new InventoryStackSnapshot(
                resultSet.getString("item_id"),
                resultSet.getLong("quantity"),
                resultSet.getLong("version")
        ),
                reward.quantity(),
                Timestamp.from(reward.occurredAt()),
                reward.userId(),
                reward.itemId()
        );
        InventoryStackSnapshot updated = stacks.stream()
                .findFirst()
                .orElseThrow(() -> new IllegalStateException("Не удалось обновить inventory stack"));
        if (updated.quantity() != expectedQuantity) {
            throw new IllegalStateException("Inventory quantity изменилась неконсистентно");
        }
        return updated;
    }

    private void appendLedger(InventoryReward reward, InventoryStackSnapshot updated) {
        jdbcTemplate.update("""
                INSERT INTO inventory_ledger (
                    ledger_entry_id,
                    user_id,
                    item_id,
                    quantity_delta,
                    quantity_after,
                    inventory_version,
                    reason_code,
                    source_type,
                    source_key,
                    created_at
                )
                VALUES (gen_random_uuid(), ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                reward.userId(),
                reward.itemId(),
                reward.quantity(),
                updated.quantity(),
                updated.version(),
                reward.reasonCode(),
                reward.sourceType(),
                reward.sourceKey(),
                Timestamp.from(reward.occurredAt())
        );
    }

    private record ExistingReward(
            String itemId,
            long quantity,
            String reasonCode,
            InventoryStackSnapshot snapshot
    ) {
    }
}
