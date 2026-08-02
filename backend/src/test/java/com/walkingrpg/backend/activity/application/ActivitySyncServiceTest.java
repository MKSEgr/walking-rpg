package com.walkingrpg.backend.activity.application;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.List;

import com.walkingrpg.backend.activity.domain.ActivityRiskStatus;
import com.walkingrpg.backend.activity.domain.ActivitySyncCalculator;
import com.walkingrpg.backend.activity.domain.ActivitySyncCommand;
import com.walkingrpg.backend.activity.domain.ActivitySyncOutcome;
import com.walkingrpg.backend.activity.infrastructure.InMemoryActivitySyncRepository;
import com.walkingrpg.backend.economy.application.EconomyService;
import com.walkingrpg.backend.economy.infrastructure.InMemoryEconomyRepository;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertThrows;

class ActivitySyncServiceTest {

    private static final Instant NOW = Instant.parse("2026-07-25T12:00:00Z");

    private final ActivitySyncService service = new ActivitySyncService(
            new InMemoryActivitySyncRepository(),
            new ActivitySyncCalculator(),
            new EconomyService(new InMemoryEconomyRepository()),
            Clock.fixed(NOW, ZoneOffset.UTC)
    );

    @Test
    void shouldReturnStoredOutcomeForRepeatedIdempotentRequest() {
        ActivitySyncCommand command = command(6_842, "same-key");

        ActivitySyncOutcome first = service.synchronize(command);
        ActivitySyncOutcome repeated = service.synchronize(command);

        assertSame(first, repeated);
        assertEquals(6_842, repeated.activity().acceptedDelta());
        assertEquals(68, repeated.activity().energyGranted());
        assertEquals(68, repeated.energyBalanceAfter());
        assertEquals(1, repeated.economyVersion());
        assertEquals(1, repeated.activity().stateVersion());
        assertEquals(NOW, repeated.activity().serverTime());
    }

    @Test
    void shouldRejectSameIdempotencyKeyForDifferentPayload() {
        service.synchronize(command(1_000, "reused-key"));

        assertThrows(
                ActivitySyncConflictException.class,
                () -> service.synchronize(command(1_100, "reused-key"))
        );
    }

    @Test
    void shouldPreserveAcceptedStateAndWalletAfterLowerTotal() {
        service.synchronize(command(4_000, "first"));

        ActivitySyncOutcome decreased = service.synchronize(command(3_500, "second"));
        ActivitySyncOutcome recovered = service.synchronize(command(4_100, "third"));

        assertEquals(ActivityRiskStatus.TOTAL_DECREASED, decreased.activity().riskStatus());
        assertEquals(4_000, decreased.activity().acceptedTotal());
        assertEquals(40, decreased.energyBalanceAfter());
        assertEquals(1, decreased.economyVersion());
        assertEquals(100, recovered.activity().acceptedDelta());
        assertEquals(1, recovered.activity().energyGranted());
        assertEquals(41, recovered.energyBalanceAfter());
        assertEquals(2, recovered.economyVersion());
        assertEquals(2, recovered.activity().stateVersion());
    }

    @Test
    void shouldRejectLocalDateThatHasNotStartedInClaimedTimeZone() {
        ActivitySyncValidationException exception = assertThrows(
                ActivitySyncValidationException.class,
                () -> service.synchronize(command(
                        100,
                        "future-date",
                        LocalDate.of(2026, 7, 26),
                        ZoneId.of("Europe/Berlin")
                ))
        );

        assertEquals("localDate", exception.field());
    }

    @Test
    void shouldAcceptDateAlreadyStartedInClaimedTimeZone() {
        ActivitySyncOutcome outcome = service.synchronize(command(
                100,
                "utc-plus-fourteen",
                LocalDate.of(2026, 7, 26),
                ZoneId.of("Pacific/Kiritimati")
        ));

        assertEquals(100, outcome.activity().acceptedTotal());
        assertEquals(1, outcome.activity().energyGranted());
    }

    private ActivitySyncCommand command(long authoritativeTotal, String idempotencyKey) {
        return command(
                authoritativeTotal,
                idempotencyKey,
                LocalDate.of(2026, 7, 25),
                ZoneId.of("Europe/Berlin")
        );
    }

    private ActivitySyncCommand command(
            long authoritativeTotal,
            String idempotencyKey,
            LocalDate localDate,
            ZoneId timeZone
    ) {
        return new ActivitySyncCommand(
                "user-1",
                "device-1",
                localDate,
                timeZone,
                authoritativeTotal,
                List.of(),
                "cursor-1",
                idempotencyKey,
                null
        );
    }
}
