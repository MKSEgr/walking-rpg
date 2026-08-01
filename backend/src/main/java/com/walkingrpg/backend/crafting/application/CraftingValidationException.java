package com.walkingrpg.backend.crafting.application;

public class CraftingValidationException extends RuntimeException {

    private final String field;

    public CraftingValidationException(String message, String field) {
        super(message);
        this.field = field;
    }

    public String field() {
        return field;
    }
}
