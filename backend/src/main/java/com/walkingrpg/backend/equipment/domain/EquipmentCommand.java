package com.walkingrpg.backend.equipment.domain;

import java.util.UUID;

public record EquipmentCommand(
        String userId,
        String slotId,
        EquipmentAction action,
        UUID itemInstanceId,
        String idempotencyKey
) {
    public EquipmentCommand {
        if (action == EquipmentAction.EQUIP && itemInstanceId == null) {
            throw new IllegalArgumentException("EQUIP требует itemInstanceId");
        }
        if (action == EquipmentAction.UNEQUIP && itemInstanceId != null) {
            throw new IllegalArgumentException("UNEQUIP не принимает itemInstanceId");
        }
    }
}
