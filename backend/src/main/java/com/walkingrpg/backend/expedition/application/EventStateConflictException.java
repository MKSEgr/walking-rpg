package com.walkingrpg.backend.expedition.application;

public class EventStateConflictException extends RuntimeException {

    private final String status;

    public EventStateConflictException(String message, String status) {
        super(message);
        this.status = status;
    }

    public String status() {
        return status;
    }
}
