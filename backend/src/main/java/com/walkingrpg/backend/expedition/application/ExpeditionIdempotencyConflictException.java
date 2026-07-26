package com.walkingrpg.backend.expedition.application;

public class ExpeditionIdempotencyConflictException extends RuntimeException {

    public ExpeditionIdempotencyConflictException() {
        super("idempotencyKey уже использован для другой команды экспедиции");
    }
}
