package com.walkingrpg.backend.equipment.domain;

import java.time.Instant;
import java.util.UUID;

public record EquipmentSlotState(
        String slotId,
        long version,
        UUID itemInstanceId,
        String itemId,
        Instant equippedAt
) {
    public EquipmentSlotState {
        if (slotId == null || slotId.isBlank()) {
            throw new IllegalArgumentException("slotId обязателен");
        }
        slotId = slotId.trim();
        if (version < 0) {
            throw new IllegalArgumentException("Equipment version не может быть отрицательной");
        }
        boolean empty = itemInstanceId == null && itemId == null && equippedAt == null;
        boolean equipped = itemInstanceId != null
                && itemId != null
                && !itemId.isBlank()
                && equippedAt != null;
        if (!empty && !equipped) {
            throw new IllegalArgumentException("Equipment slot state заполнен частично");
        }
        if (equipped) {
            itemId = itemId.trim();
        }
    }

    public static EquipmentSlotState empty(String slotId) {
        return new EquipmentSlotState(slotId, 0, null, null, null);
    }

    public boolean isEquipped() {
        return itemInstanceId != null;
    }
}
