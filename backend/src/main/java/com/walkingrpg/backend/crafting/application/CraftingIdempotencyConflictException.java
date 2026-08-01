package com.walkingrpg.backend.crafting.application;

public class CraftingIdempotencyConflictException extends RuntimeException {

    public CraftingIdempotencyConflictException() {
        super("Idempotency key уже использован для другой crafting-команды");
    }
}
