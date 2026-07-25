package com.walkingrpg.backend.activity.domain;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

class ActivitySyncCalculatorTest {

    private static final Instant SERVER_TIME = Instant.parse("2026-07-25T12:00:00Z");

    private final ActivitySyncCalculator calculator = new ActivitySyncCalculator();

    @Test
    void shouldGrantEnergyForEveryCrossedHundredStepThreshold() {
        ActivitySyncResult result = calculator.calculate(
                new ActivityDayState(99, 4),
                command(100),
                SERVER_TIME
        );

        assertEquals(100, result.acceptedTotal());
        assertEquals(1, result.acceptedDelta());
        assertEquals(1, result.energyGranted());
        assertEquals(ActivityRiskStatus.ACCEPTED, result.riskStatus());
        assertEquals(5, result.stateVersion());
    }

    @Test
    void shouldNotLoseStepRemainderAcrossFrequentSynchronizations() {
        ActivitySyncResult result = calculator.calculate(
                new ActivityDayState(6_842, 10),
                command(7_000),
                SERVER_TIME
        );

        assertEquals(158, result.acceptedDelta());
        assertEquals(2, result.energyGranted());
    }

    @Test
    void shouldNotReduceAcceptedStateWhenAuthoritativeTotalDecreases() {
        ActivitySyncResult result = calculator.calculate(
                new ActivityDayState(4_000, 7),
                command(3_500),
                SERVER_TIME
        );

        assertEquals(4_000, result.acceptedTotal());
        assertEquals(0, result.acceptedDelta());
        assertEquals(0, result.energyGranted());
        assertEquals(ActivityRiskStatus.TOTAL_DECREASED, result.riskStatus());
        assertEquals(7, result.stateVersion());
    }

    private ActivitySyncCommand command(long authoritativeTotal) {
        return new ActivitySyncCommand(
                "user-1",
                "device-1",
                LocalDate.of(2026, 7, 25),
                ZoneId.of("Europe/Berlin"),
                authoritativeTotal,
                List.of(),
                null,
                "sync-1",
                null
        );
    }
}
