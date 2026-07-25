package com.walkingrpg.backend.economy.domain;

public class EconomyLedgerConflictException extends RuntimeException {

    public EconomyLedgerConflictException(String message) {
        super(message);
    }
}
