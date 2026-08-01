package com.walkingrpg.backend.equipment.application;

public class EquipmentItemUnavailableException extends RuntimeException {

    private final String itemReference;

    public EquipmentItemUnavailableException(Object itemReference) {
        super("Уникальный предмет недоступен для этого equipment slot");
        this.itemReference = String.valueOf(itemReference);
    }

    public String itemReference() {
        return itemReference;
    }
}
