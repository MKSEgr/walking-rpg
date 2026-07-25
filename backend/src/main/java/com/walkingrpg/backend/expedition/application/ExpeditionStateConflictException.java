package com.walkingrpg.backend.expedition.application;

import com.walkingrpg.backend.expedition.domain.ExpeditionProgressStatus;

public class ExpeditionStateConflictException extends RuntimeException {

    private final ExpeditionProgressStatus status;
    private final long remainingEnergy;

    public ExpeditionStateConflictException(
            String message,
            ExpeditionProgressStatus status,
            long remainingEnergy
    ) {
        super(message);
        this.status = status;
        this.remainingEnergy = remainingEnergy;
    }

    public ExpeditionProgressStatus status() {
        return status;
    }

    public long remainingEnergy() {
        return remainingEnergy;
    }
}
