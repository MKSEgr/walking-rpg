package com.walkingrpg.backend.home.application;

public class HomeQueryValidationException extends RuntimeException {

    private final String field;

    public HomeQueryValidationException(String field, String message) {
        super(message);
        this.field = field;
    }

    public String field() {
        return field;
    }
}
