package com.walkingrpg.backend.itemupgrade.application;

public class ItemUpgradeIdempotencyConflictException extends RuntimeException {

    public ItemUpgradeIdempotencyConflictException() {
        super("Idempotency key уже использован для другого item upgrade");
    }
}
