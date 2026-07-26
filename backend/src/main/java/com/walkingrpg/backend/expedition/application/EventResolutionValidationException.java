package com.walkingrpg.backend.expedition.application;

public class EventResolutionValidationException extends RuntimeException {

    private final String field;

    public EventResolutionValidationException(String message, String field) {
        super(message);
        this.field = field;
    }

    public String field() {
        return field;
    }
}
