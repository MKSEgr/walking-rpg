package com.walkingrpg.backend.equipment.domain;

public record EquipmentIdempotencyScope(
        String userId,
        String slotId,
        String idempotencyKey
) {
    public static EquipmentIdempotencyScope from(EquipmentCommand command) {
        return new EquipmentIdempotencyScope(
                command.userId(),
                command.slotId(),
                command.idempotencyKey()
        );
    }
}
