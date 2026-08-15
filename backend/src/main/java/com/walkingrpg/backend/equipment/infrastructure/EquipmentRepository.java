package com.walkingrpg.backend.equipment.infrastructure;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import com.walkingrpg.backend.equipment.domain.EquipmentAction;
import com.walkingrpg.backend.equipment.domain.EquipmentIdempotencyScope;
import com.walkingrpg.backend.equipment.domain.EquipmentResult;
import com.walkingrpg.backend.equipment.domain.EquipmentSlotDefinition;
import com.walkingrpg.backend.equipment.domain.EquipmentSlotState;
import com.walkingrpg.backend.equipment.domain.ProcessedEquipmentCommand;
import com.walkingrpg.backend.equipment.domain.UniqueInventoryItemReference;
import com.walkingrpg.backend.inventory.domain.InventoryItemDefinition;

public interface EquipmentRepository {

    void acquireLock(String userId);

    Optional<ProcessedEquipmentCommand> findProcessed(
            EquipmentIdempotencyScope scope
    );

    Optional<UniqueInventoryItemReference> lockOwnedUniqueItem(
            String userId,
            UUID itemInstanceId
    );

    EquipmentResult apply(
            EquipmentIdempotencyScope scope,
            String requestFingerprint,
            String contentVersion,
            EquipmentAction action,
            EquipmentSlotDefinition slot,
            UniqueInventoryItemReference itemReference,
            InventoryItemDefinition itemDefinition,
            Instant serverTime
    );

    List<EquipmentSlotState> findAll(String userId);

    boolean isEquipped(String userId, String slotId, String itemId);

    default boolean isEquipped(
            String userId,
            String slotId,
            String itemId,
            long minimumUpgradeLevel
    ) {
        return minimumUpgradeLevel <= 1 && isEquipped(userId, slotId, itemId);
    }
}
