package com.walkingrpg.backend.economy.infrastructure;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;

import com.walkingrpg.backend.economy.domain.EconomyCredit;
import com.walkingrpg.backend.economy.domain.EconomyCurrency;
import com.walkingrpg.backend.economy.domain.EconomyLedgerConflictException;
import com.walkingrpg.backend.economy.domain.WalletSnapshot;

public class InMemoryEconomyRepository implements EconomyRepository {

    private final Map<WalletKey, WalletSnapshot> wallets = new HashMap<>();
    private final Map<LedgerKey, StoredCredit> credits = new HashMap<>();

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
        WalletKey walletKey = new WalletKey(credit.userId(), credit.currency());
        LedgerKey ledgerKey = new LedgerKey(
                credit.userId(),
                credit.currency(),
                credit.sourceType(),
                credit.sourceKey()
        );
        StoredCredit existing = credits.get(ledgerKey);

        if (existing != null) {
            if (existing.amount() != credit.amount()
                    || !existing.reasonCode().equals(credit.reasonCode())) {
                throw new EconomyLedgerConflictException(
                        "Источник ledger уже использован для другого начисления"
                );
            }
            return existing.walletSnapshot();
        }

        WalletSnapshot current = wallets.getOrDefault(walletKey, new WalletSnapshot(0, 0));
        WalletSnapshot updated = new WalletSnapshot(
                current.balance() + credit.amount(),
                current.version() + 1
        );
        wallets.put(walletKey, updated);
        credits.put(ledgerKey, new StoredCredit(
                credit.amount(),
                credit.reasonCode(),
                updated
        ));
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

    private record StoredCredit(
            long amount,
            String reasonCode,
            WalletSnapshot walletSnapshot
    ) {
    }
}
