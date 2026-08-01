package com.walkingrpg.backend.equipment.application;

public class EquipmentIdempotencyConflictException extends RuntimeException {

    public EquipmentIdempotencyConflictException() {
        super("Idempotency key уже использован для другой equipment-команды");
    }
}
