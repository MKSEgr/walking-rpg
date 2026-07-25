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
import com.walkingrpg.backend.activity.domain.ActivitySyncResult;
import com.walkingrpg.backend.activity.infrastructure.InMemoryActivitySyncRepository;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertThrows;

class ActivitySyncServiceTest {

    private static final Instant NOW = Instant.parse("2026-07-25T12:00:00Z");

    private final ActivitySyncService service = new ActivitySyncService(
            new InMemoryActivitySyncRepository(),
            new ActivitySyncCalculator(),
            Clock.fixed(NOW, ZoneOffset.UTC)
    );

    @Test
    void shouldReturnStoredResultForRepeatedIdempotentRequest() {
        ActivitySyncCommand command = command(6_842, "same-key");

        ActivitySyncResult first = service.synchronize(command);
        ActivitySyncResult repeated = service.synchronize(command);

        assertSame(first, repeated);
        assertEquals(6_842, repeated.acceptedDelta());
        assertEquals(68, repeated.energyGranted());
        assertEquals(1, repeated.stateVersion());
        assertEquals(NOW, repeated.serverTime());
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
    void shouldPreserveAcceptedStateAfterLowerTotal() {
        service.synchronize(command(4_000, "first"));

        ActivitySyncResult decreased = service.synchronize(command(3_500, "second"));
        ActivitySyncResult recovered = service.synchronize(command(4_100, "third"));

        assertEquals(ActivityRiskStatus.TOTAL_DECREASED, decreased.riskStatus());
        assertEquals(4_000, decreased.acceptedTotal());
        assertEquals(100, recovered.acceptedDelta());
        assertEquals(1, recovered.energyGranted());
        assertEquals(2, recovered.stateVersion());
    }

    private ActivitySyncCommand command(long authoritativeTotal, String idempotencyKey) {
        return new ActivitySyncCommand(
                "user-1",
                "device-1",
                LocalDate.of(2026, 7, 25),
                ZoneId.of("Europe/Berlin"),
                authoritativeTotal,
                List.of(),
                "cursor-1",
                idempotencyKey,
                null
        );
    }
}
