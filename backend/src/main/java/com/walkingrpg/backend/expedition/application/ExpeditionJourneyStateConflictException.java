package com.walkingrpg.backend.expedition.application;

import com.walkingrpg.backend.expedition.domain.ExpeditionProgressStatus;

public class ExpeditionJourneyStateConflictException extends RuntimeException {

    private final ExpeditionProgressStatus status;
    private final long expectedJourneyNumber;
    private final long currentJourneyNumber;

    public ExpeditionJourneyStateConflictException(
            String message,
            ExpeditionProgressStatus status,
            long expectedJourneyNumber,
            long currentJourneyNumber
    ) {
        super(message);
        this.status = status;
        this.expectedJourneyNumber = expectedJourneyNumber;
        this.currentJourneyNumber = currentJourneyNumber;
    }

    public ExpeditionProgressStatus status() {
        return status;
    }

    public long expectedJourneyNumber() {
        return expectedJourneyNumber;
    }

    public long currentJourneyNumber() {
        return currentJourneyNumber;
    }
}
