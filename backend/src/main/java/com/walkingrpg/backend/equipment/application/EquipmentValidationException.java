package com.walkingrpg.backend.equipment.application;

public class EquipmentValidationException extends RuntimeException {

    private final String field;

    public EquipmentValidationException(String message, String field) {
        super(message);
        this.field = field;
    }

    public String field() {
        return field;
    }
}
