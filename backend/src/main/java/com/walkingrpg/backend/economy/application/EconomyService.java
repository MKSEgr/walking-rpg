package com.walkingrpg.backend.economy.application;

import java.time.Instant;

import com.walkingrpg.backend.economy.domain.EconomyCredit;
import com.walkingrpg.backend.economy.domain.EconomyCurrency;
import com.walkingrpg.backend.economy.domain.EconomyDebit;
import com.walkingrpg.backend.economy.domain.WalletSnapshot;
import com.walkingrpg.backend.economy.infrastructure.EconomyRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class EconomyService {

    static final String ACTIVITY_REASON = "ACTIVITY_STEPS";
    static final String ACTIVITY_SOURCE_TYPE = "ACTIVITY_SYNC";
    static final String EXPEDITION_REASON = "EXPEDITION_PROGRESS";
    static final String EXPEDITION_SOURCE_TYPE = "EXPEDITION_ADVANCE";

    private final EconomyRepository repository;

    public EconomyService(EconomyRepository repository) {
        this.repository = repository;
    }

    @Transactional
    public WalletSnapshot creditActivityEnergy(
            String userId,
            long energyGranted,
            String sourceKey,
            Instant occurredAt
    ) {
        if (energyGranted < 0) {
            throw new IllegalArgumentException("energyGranted не может быть отрицательной");
        }

        if (energyGranted == 0) {
            return repository.currentBalance(userId, EconomyCurrency.ENERGY, occurredAt);
        }

        return repository.applyCredit(new EconomyCredit(
                userId,
                EconomyCurrency.ENERGY,
                energyGranted,
                ACTIVITY_REASON,
                ACTIVITY_SOURCE_TYPE,
                sourceKey,
                occurredAt
        ));
    }

    @Transactional
    public WalletSnapshot debitEnergy(
            String userId,
            long energyToSpend,
            String reasonCode,
            String sourceType,
            String sourceKey,
            Instant occurredAt
    ) {
        if (energyToSpend <= 0) {
            throw new IllegalArgumentException("energyToSpend должна быть положительной");
        }
        return repository.applyDebit(new EconomyDebit(
                userId,
                EconomyCurrency.ENERGY,
                energyToSpend,
                reasonCode,
                sourceType,
                sourceKey,
                occurredAt
        ));
    }

    @Transactional
    public WalletSnapshot debitExpeditionEnergy(
            String userId,
            long energyToSpend,
            String sourceKey,
            Instant occurredAt
    ) {
        if (energyToSpend <= 0) {
            throw new IllegalArgumentException("energyToSpend должна быть положительной");
        }

        return repository.applyDebit(new EconomyDebit(
                userId,
                EconomyCurrency.ENERGY,
                energyToSpend,
                EXPEDITION_REASON,
                EXPEDITION_SOURCE_TYPE,
                sourceKey,
                occurredAt
        ));
    }
}
