package com.walkingrpg.backend.equipment.application;

public class EquipmentSlotNotFoundException extends RuntimeException {

    private final String slotId;

    public EquipmentSlotNotFoundException(String slotId) {
        super("Equipment slot не найден: " + slotId);
        this.slotId = slotId;
    }

    public String slotId() {
        return slotId;
    }
}
