package com.walkingrpg.backend.activity.domain;

import java.time.Instant;

import org.springframework.stereotype.Component;

@Component
public class ActivitySyncCalculator {

    static final long STEPS_PER_ENERGY = 100;

    public ActivitySyncResult calculate(
            ActivityDayState currentState,
            ActivitySyncCommand command,
            Instant serverTime
    ) {
        long requestedTotal = command.authoritativeTotal();
        long currentTotal = currentState.acceptedTotal();

        if (requestedTotal < currentTotal) {
            return new ActivitySyncResult(
                    currentTotal,
                    0,
                    0,
                    ActivityRiskStatus.TOTAL_DECREASED,
                    currentState.stateVersion(),
                    serverTime
            );
        }

        long acceptedDelta = requestedTotal - currentTotal;
        long energyGranted = completedEnergyUnits(requestedTotal)
                - completedEnergyUnits(currentTotal);
        long stateVersion = acceptedDelta > 0
                ? currentState.stateVersion() + 1
                : currentState.stateVersion();
        ActivityRiskStatus riskStatus = acceptedDelta > 0
                ? ActivityRiskStatus.ACCEPTED
                : ActivityRiskStatus.NO_NEW_ACTIVITY;

        return new ActivitySyncResult(
                requestedTotal,
                acceptedDelta,
                energyGranted,
                riskStatus,
                stateVersion,
                serverTime
        );
    }

    private long completedEnergyUnits(long steps) {
        return steps / STEPS_PER_ENERGY;
    }
}
