package com.walkingrpg.backend.inventory.infrastructure;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import com.walkingrpg.backend.inventory.domain.InventoryLedgerConflictException;
import com.walkingrpg.backend.inventory.domain.InventoryReward;
import com.walkingrpg.backend.inventory.domain.InventoryStackSnapshot;

public class InMemoryInventoryRepository implements InventoryRepository {

    private final Map<StackKey, InventoryStackSnapshot> stacks = new HashMap<>();
    private final Map<LedgerKey, StoredReward> rewards = new HashMap<>();

    @Override
    public synchronized InventoryStackSnapshot applyReward(InventoryReward reward) {
        StackKey stackKey = new StackKey(reward.userId(), reward.itemId());
        LedgerKey ledgerKey = new LedgerKey(
                reward.userId(),
                reward.sourceType(),
                reward.sourceKey()
        );
        StoredReward existing = rewards.get(ledgerKey);
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

        InventoryStackSnapshot current = stacks.getOrDefault(
                stackKey,
                new InventoryStackSnapshot(reward.itemId(), 0, 0)
        );
        InventoryStackSnapshot updated = new InventoryStackSnapshot(
                reward.itemId(),
                Math.addExact(current.quantity(), reward.quantity()),
                current.version() + 1
        );
        stacks.put(stackKey, updated);
        rewards.put(ledgerKey, new StoredReward(
                reward.itemId(),
                reward.quantity(),
                reward.reasonCode(),
                updated
        ));
        return updated;
    }

    @Override
    public synchronized List<InventoryStackSnapshot> findAll(String userId) {
        List<InventoryStackSnapshot> result = new ArrayList<>();
        stacks.forEach((key, value) -> {
            if (key.userId().equals(userId) && value.quantity() > 0) {
                result.add(value);
            }
        });
        result.sort((left, right) -> left.itemId().compareTo(right.itemId()));
        return List.copyOf(result);
    }

    private record StackKey(String userId, String itemId) {
    }

    private record LedgerKey(
            String userId,
            String sourceType,
            String sourceKey
    ) {
    }

    private record StoredReward(
            String itemId,
            long quantity,
            String reasonCode,
            InventoryStackSnapshot snapshot
    ) {
    }
}
