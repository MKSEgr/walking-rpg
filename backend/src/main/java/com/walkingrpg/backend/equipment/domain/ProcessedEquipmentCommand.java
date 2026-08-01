package com.walkingrpg.backend.equipment.domain;

public record ProcessedEquipmentCommand(
        String requestFingerprint,
        EquipmentResult result
) {
}
