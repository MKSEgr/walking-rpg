package com.walkingrpg.backend.equipment.api;

import java.time.Instant;

public record EquipmentResponse(
        String contentVersion,
        String slotId,
        String slotName,
        String slotDescription,
        String action,
        boolean changed,
        long version,
        EquippedItemResponse equippedItem,
        Instant serverTime
) {
}
