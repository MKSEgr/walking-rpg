package com.walkingrpg.backend.itemupgrade.application;

public class ItemUpgradeValidationException extends RuntimeException {

    private final String field;

    public ItemUpgradeValidationException(String message, String field) {
        super(message);
        this.field = field;
    }

    public String field() {
        return field;
    }
}
