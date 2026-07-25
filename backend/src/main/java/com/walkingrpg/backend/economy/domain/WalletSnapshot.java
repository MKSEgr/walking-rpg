package com.walkingrpg.backend.economy.domain;

public record WalletSnapshot(
        long balance,
        long version
) {
    public WalletSnapshot {
        if (balance < 0) {
            throw new IllegalArgumentException("Баланс не может быть отрицательным");
        }
        if (version < 0) {
            throw new IllegalArgumentException("Версия кошелька не может быть отрицательной");
        }
    }
}
