package com.walkingrpg.backend.economy.infrastructure;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;

import com.walkingrpg.backend.economy.domain.EconomyCredit;
import com.walkingrpg.backend.economy.domain.EconomyCurrency;
import com.walkingrpg.backend.economy.domain.EconomyDebit;
import com.walkingrpg.backend.economy.domain.EconomyLedgerConflictException;
import com.walkingrpg.backend.economy.domain.InsufficientEnergyException;
import com.walkingrpg.backend.economy.domain.WalletSnapshot;

public class InMemoryEconomyRepository implements EconomyRepository {

    private final Map<WalletKey, WalletSnapshot> wallets = new HashMap<>();
    private final Map<LedgerKey, StoredChange> changes = new HashMap<>();

    @Override
    public synchronized WalletSnapshot currentBalance(
            String userId,
            EconomyCurrency currency,
            Instant observedAt
    ) {
        return wallets.computeIfAbsent(
                new WalletKey(userId, currency),
                ignored -> new WalletSnapshot(0, 0)
        );
    }

    @Override
    public synchronized WalletSnapshot applyCredit(EconomyCredit credit) {
        return applyChange(
                credit.userId(),
                credit.currency(),
                credit.amount(),
                credit.reasonCode(),
                credit.sourceType(),
                credit.sourceKey()
        );
    }

    @Override
    public synchronized WalletSnapshot applyDebit(EconomyDebit debit) {
        return applyChange(
                debit.userId(),
                debit.currency(),
                -debit.amount(),
                debit.reasonCode(),
                debit.sourceType(),
                debit.sourceKey()
        );
    }

    private WalletSnapshot applyChange(
            String userId,
            EconomyCurrency currency,
            long signedAmount,
            String reasonCode,
            String sourceType,
            String sourceKey
    ) {
        WalletKey walletKey = new WalletKey(userId, currency);
        LedgerKey ledgerKey = new LedgerKey(userId, currency, sourceType, sourceKey);
        StoredChange existing = changes.get(ledgerKey);
        if (existing != null) {
            if (existing.signedAmount() != signedAmount
                    || !existing.reasonCode().equals(reasonCode)) {
                throw new EconomyLedgerConflictException(
                        "Источник ledger уже использован для другой операции"
                );
            }
            return existing.walletSnapshot();
        }

        WalletSnapshot current = wallets.getOrDefault(walletKey, new WalletSnapshot(0, 0));
        if (signedAmount < 0 && current.balance() < -signedAmount) {
            throw new InsufficientEnergyException(current.balance(), -signedAmount);
        }

        WalletSnapshot updated = new WalletSnapshot(
                current.balance() + signedAmount,
                current.version() + 1
        );
        wallets.put(walletKey, updated);
        changes.put(ledgerKey, new StoredChange(signedAmount, reasonCode, updated));
        return updated;
    }

    private record WalletKey(String userId, EconomyCurrency currency) {
    }

    private record LedgerKey(
            String userId,
            EconomyCurrency currency,
            String sourceType,
            String sourceKey
    ) {
    }

    private record StoredChange(
            long signedAmount,
            String reasonCode,
            WalletSnapshot walletSnapshot
    ) {
    }
}
