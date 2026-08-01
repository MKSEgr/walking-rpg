package com.walkingrpg.backend.expedition.domain;

import java.util.Objects;

import com.walkingrpg.backend.inventory.domain.InventoryItemDefinition;
import com.walkingrpg.backend.inventory.domain.InventoryItemKind;

public record ExpeditionChoiceEquipmentRequirement(
        String slotId,
        String slotName,
        InventoryItemDefinition item,
        String lockedReason
) {
    public ExpeditionChoiceEquipmentRequirement {
        slotId = requireText(slotId, "slotId");
        slotName = requireText(slotName, "slotName");
        Objects.requireNonNull(item, "item");
        lockedReason = requireText(lockedReason, "lockedReason");
        if (item.kind() != InventoryItemKind.UNIQUE) {
            throw new IllegalArgumentException(
                    "Equipment requirement должен ссылаться на unique item"
            );
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
