package com.walkingrpg.backend.expedition.application;

public class ExpeditionValidationException extends RuntimeException {

    private final String field;

    public ExpeditionValidationException(String message, String field) {
        super(message);
        this.field = field;
    }

    public String field() {
        return field;
    }
}
