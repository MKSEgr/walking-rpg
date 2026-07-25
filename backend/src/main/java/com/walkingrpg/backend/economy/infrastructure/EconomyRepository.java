package com.walkingrpg.backend.economy.infrastructure;

import java.time.Instant;

import com.walkingrpg.backend.economy.domain.EconomyCredit;
import com.walkingrpg.backend.economy.domain.EconomyCurrency;
import com.walkingrpg.backend.economy.domain.EconomyDebit;
import com.walkingrpg.backend.economy.domain.WalletSnapshot;

public interface EconomyRepository {

    WalletSnapshot currentBalance(
            String userId,
            EconomyCurrency currency,
            Instant observedAt
    );

    WalletSnapshot applyCredit(EconomyCredit credit);

    WalletSnapshot applyDebit(EconomyDebit debit);
}
