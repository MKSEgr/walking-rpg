package com.walkingrpg.backend.platform.application;

public class PlatformValidationException extends RuntimeException {

    private final String field;

    public PlatformValidationException(String message, String field) {
        super(message);
        this.field = field;
    }

    public String field() {
        return field;
    }
}
