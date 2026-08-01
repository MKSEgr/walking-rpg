package com.walkingrpg.backend.home.domain;

public record EquipmentSlotSnapshot(
        String slotId,
        String name,
        String description,
        String status,
        long version,
        EquipmentItemSnapshot item
) {
}
