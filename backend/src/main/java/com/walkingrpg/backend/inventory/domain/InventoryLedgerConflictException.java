package com.walkingrpg.backend.inventory.domain;

public class InventoryLedgerConflictException extends RuntimeException {

    public InventoryLedgerConflictException(String message) {
        super(message);
    }
}
