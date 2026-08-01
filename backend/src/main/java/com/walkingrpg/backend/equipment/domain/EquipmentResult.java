package com.walkingrpg.backend.equipment.domain;

import java.time.Instant;
import java.util.Objects;

public record EquipmentResult(
        String contentVersion,
        String slotId,
        String slotName,
        String slotDescription,
        EquipmentAction action,
        boolean changed,
        long version,
        EquippedItemResult equippedItem,
        Instant serverTime
) {
    public EquipmentResult {
        contentVersion = requireText(contentVersion, "contentVersion");
        slotId = requireText(slotId, "slotId");
        slotName = requireText(slotName, "slotName");
        slotDescription = requireText(slotDescription, "slotDescription");
        Objects.requireNonNull(action, "action");
        Objects.requireNonNull(serverTime, "serverTime");
        if (version < 0) {
            throw new IllegalArgumentException("Equipment version не может быть отрицательной");
        }
        if (action == EquipmentAction.EQUIP && equippedItem == null) {
            throw new IllegalArgumentException("EQUIP result требует equippedItem");
        }
        if (action == EquipmentAction.UNEQUIP && equippedItem != null) {
            throw new IllegalArgumentException("UNEQUIP result не должен содержать item");
        }
    }

    private static String requireText(String value, String field) {
        Objects.requireNonNull(value, field);
        String normalized = value.trim();
        if (normalized.isEmpty()) {
            throw new IllegalArgumentException(field + " обязателен");
        }
        return normalized;
    }
}
