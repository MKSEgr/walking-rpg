package com.walkingrpg.backend.activity.application;

public class ActivitySyncValidationException extends RuntimeException {

    private final String field;

    public ActivitySyncValidationException(String field, String message) {
        super(message);
        this.field = field;
    }

    public String field() {
        return field;
    }
}
