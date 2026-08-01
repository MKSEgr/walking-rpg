package com.walkingrpg.backend.equipment.infrastructure;

import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import com.walkingrpg.backend.equipment.domain.EquipmentAction;
import com.walkingrpg.backend.equipment.domain.EquipmentIdempotencyScope;
import com.walkingrpg.backend.equipment.domain.EquipmentResult;
import com.walkingrpg.backend.equipment.domain.EquipmentSlotDefinition;
import com.walkingrpg.backend.equipment.domain.EquipmentSlotState;
import com.walkingrpg.backend.equipment.domain.EquippedItemResult;
import com.walkingrpg.backend.equipment.domain.ProcessedEquipmentCommand;
import com.walkingrpg.backend.equipment.domain.UniqueInventoryItemReference;
import com.walkingrpg.backend.inventory.domain.InventoryItemDefinition;

public class InMemoryEquipmentRepository implements EquipmentRepository {

    private final Map<ScopeKey, ProcessedEquipmentCommand> processed =
            new HashMap<>();
    private final Map<UUID, OwnedItem> items = new HashMap<>();
    private final Map<SlotKey, EquipmentSlotState> slots = new HashMap<>();

    @Override
    public synchronized void acquireLock(String userId) {
        // synchronized methods provide the in-memory test lock.
    }

    @Override
    public synchronized Optional<ProcessedEquipmentCommand> findProcessed(
            EquipmentIdempotencyScope scope
    ) {
        return Optional.ofNullable(processed.get(ScopeKey.from(scope)));
    }

    @Override
    public synchronized Optional<UniqueInventoryItemReference> lockOwnedUniqueItem(
            String userId,
            UUID itemInstanceId
    ) {
        OwnedItem item = items.get(itemInstanceId);
        if (item == null || !item.userId().equals(userId)) {
            return Optional.empty();
        }
        return Optional.of(new UniqueInventoryItemReference(
                itemInstanceId,
                item.itemId()
        ));
    }

    @Override
    public synchronized EquipmentResult apply(
            EquipmentIdempotencyScope scope,
            String requestFingerprint,
            String contentVersion,
            EquipmentAction action,
            EquipmentSlotDefinition slot,
            UniqueInventoryItemReference itemReference,
            InventoryItemDefinition itemDefinition,
            Instant serverTime
    ) {
        SlotKey key = new SlotKey(scope.userId(), scope.slotId());
        EquipmentSlotState current = slots.getOrDefault(
                key,
                EquipmentSlotState.empty(scope.slotId())
        );
        EquipmentSlotState updated;
        boolean changed;
        EquippedItemResult equippedItem;
        if (action == EquipmentAction.EQUIP) {
            changed = !itemReference.itemInstanceId().equals(
                    current.itemInstanceId()
            );
            updated = changed
                    ? new EquipmentSlotState(
                            scope.slotId(),
                            current.version() + 1,
                            itemReference.itemInstanceId(),
                            itemReference.itemId(),
                            serverTime
                    )
                    : current;
            slots.put(key, updated);
            equippedItem = new EquippedItemResult(
                    updated.itemInstanceId(),
                    itemDefinition.itemId(),
                    itemDefinition.name(),
                    itemDefinition.description(),
                    updated.equippedAt()
            );
        } else {
            changed = current.isEquipped();
            updated = changed
                    ? new EquipmentSlotState(
                            scope.slotId(),
                            current.version() + 1,
                            null,
                            null,
                            null
                    )
                    : current;
            if (changed) {
                slots.put(key, updated);
            }
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
        processed.put(
                ScopeKey.from(scope),
                new ProcessedEquipmentCommand(requestFingerprint, result)
        );
        return result;
    }

    @Override
    public synchronized List<EquipmentSlotState> findAll(String userId) {
        return slots.entrySet().stream()
                .filter(entry -> entry.getKey().userId().equals(userId))
                .map(Map.Entry::getValue)
                .sorted((left, right) -> left.slotId().compareTo(right.slotId()))
                .toList();
    }

    @Override
    public synchronized boolean isEquipped(
            String userId,
            String slotId,
            String itemId
    ) {
        EquipmentSlotState state = slots.get(new SlotKey(userId, slotId));
        return state != null && itemId.equals(state.itemId());
    }

    public synchronized void putUniqueItem(
            String userId,
            UUID itemInstanceId,
            String itemId
    ) {
        items.put(itemInstanceId, new OwnedItem(userId, itemId));
    }

    private record ScopeKey(
            String userId,
            String slotId,
            String idempotencyKey
    ) {
        private static ScopeKey from(EquipmentIdempotencyScope scope) {
            return new ScopeKey(
                    scope.userId(),
                    scope.slotId(),
                    scope.idempotencyKey()
            );
        }
    }

    private record SlotKey(String userId, String slotId) {
    }

    private record OwnedItem(String userId, String itemId) {
    }
}
