package com.walkingrpg.backend.expedition.application;

public class EventResolutionIdempotencyConflictException extends RuntimeException {

    public EventResolutionIdempotencyConflictException() {
        super("idempotencyKey уже использован для другого выбора события");
    }
}
