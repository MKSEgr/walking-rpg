package com.walkingrpg.backend.economy.application;

import java.time.Instant;

import com.walkingrpg.backend.economy.domain.EconomyCredit;
import com.walkingrpg.backend.economy.domain.EconomyCurrency;
import com.walkingrpg.backend.economy.domain.WalletSnapshot;
import com.walkingrpg.backend.economy.infrastructure.EconomyRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class EconomyService {

    static final String ACTIVITY_REASON = "ACTIVITY_STEPS";
    static final String ACTIVITY_SOURCE_TYPE = "ACTIVITY_SYNC";

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
}
