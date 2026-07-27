package com.walkingrpg.backend.platform.application;

public class PlatformIdempotencyConflictException extends RuntimeException {

    public PlatformIdempotencyConflictException() {
        super("idempotencyKey уже использован для другой platform-команды");
    }
}
