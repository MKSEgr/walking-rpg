package com.walkingrpg.backend.equipment.domain;

import java.util.Objects;

public record EquipmentSlotDefinition(
        String slotId,
        String name,
        String description
) {
    public EquipmentSlotDefinition {
        slotId = requireText(slotId, "slotId");
        name = requireText(name, "name");
        description = requireText(description, "description");
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
