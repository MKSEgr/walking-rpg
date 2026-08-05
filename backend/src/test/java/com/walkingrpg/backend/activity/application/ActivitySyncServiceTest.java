package com.walkingrpg.backend.activity.application;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;

import com.walkingrpg.backend.activity.domain.ActivityRiskStatus;
import com.walkingrpg.backend.activity.domain.ActivitySyncCalculator;
import com.walkingrpg.backend.activity.domain.ActivitySyncCommand;
import com.walkingrpg.backend.activity.domain.ActivitySyncOutcome;
import com.walkingrpg.backend.activity.infrastructure.InMemoryActivitySyncRepository;
import com.walkingrpg.backend.economy.application.EconomyService;
import com.walkingrpg.backend.economy.infrastructure.InMemoryEconomyRepository;
import com.walkingrpg.backend.risk.application.ActivityRiskEvaluator;
import com.walkingrpg.backend.risk.application.ActivityRiskRecorder;
import com.walkingrpg.backend.risk.domain.ActivityRiskAssessment;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

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
    void shouldEvaluateChangedAttestationOnEveryExactReplay() {
        List<ActivityRiskAssessment> assessments = new ArrayList<>();
        ActivityRiskEvaluator evaluator = new ActivityRiskEvaluator();
        ActivityRiskRecorder recorder = (command, previousState, result, createdAt) -> {
            ActivityRiskAssessment assessment = evaluator.evaluate(
                    command,
                    previousState,
                    result,
                    createdAt
            );
            assessments.add(assessment);
            return assessment;
        };
        ActivitySyncService replayAuditedService = new ActivitySyncService(
                new InMemoryActivitySyncRepository(),
                new ActivitySyncCalculator(),
                new EconomyService(new InMemoryEconomyRepository()),
                recorder,
                Clock.fixed(NOW, ZoneOffset.UTC)
        );

        ActivitySyncOutcome first = replayAuditedService.synchronize(command(
                6_842,
                "attestation-replay",
                LocalDate.of(2026, 7, 25),
                ZoneId.of("Europe/Berlin"),
                "signed-attestation"
        ));
        ActivitySyncOutcome replayed = replayAuditedService.synchronize(command(
                6_842,
                "attestation-replay",
                LocalDate.of(2026, 7, 25),
                ZoneId.of("Europe/Berlin"),
                null
        ));

        assertSame(first, replayed);
        assertEquals(2, assessments.size());
        assertEquals(6_842, assessments.getFirst().acceptedDelta());
        assertFalse(assessments.getFirst().signals().contains("ATTESTATION_MISSING"));
        assertEquals(0, assessments.getLast().acceptedDelta());
        assertTrue(assessments.getLast().signals().contains("ATTESTATION_MISSING"));
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

    @Test
    void shouldTimestampSynchronizationAfterUserLock() {
        MutableClock clock = new MutableClock(NOW.minusSeconds(30));
        InMemoryActivitySyncRepository repository =
                new InMemoryActivitySyncRepository() {
                    @Override
                    public void acquireUserLock(String userId) {
                        clock.set(NOW);
                    }
                };
        ActivitySyncService orderedService = new ActivitySyncService(
                repository,
                new ActivitySyncCalculator(),
                new EconomyService(new InMemoryEconomyRepository()),
                clock
        );

        ActivitySyncOutcome outcome = orderedService.synchronize(command(
                100,
                "lock-time-order"
        ));

        assertEquals(NOW, outcome.activity().serverTime());
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
        return command(
                authoritativeTotal,
                idempotencyKey,
                localDate,
                timeZone,
                null
        );
    }

    private ActivitySyncCommand command(
            long authoritativeTotal,
            String idempotencyKey,
            LocalDate localDate,
            ZoneId timeZone,
            String attestation
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
                attestation
        );
    }

    private static final class MutableClock extends Clock {
        private Instant current;
        private final ZoneId zone;

        private MutableClock(Instant current) {
            this(current, ZoneOffset.UTC);
        }

        private MutableClock(Instant current, ZoneId zone) {
            this.current = current;
            this.zone = zone;
        }

        @Override
        public ZoneId getZone() {
            return zone;
        }

        @Override
        public synchronized Clock withZone(ZoneId requestedZone) {
            return zone.equals(requestedZone)
                    ? this
                    : new MutableClock(current, requestedZone);
        }

        @Override
        public synchronized Instant instant() {
            return current;
        }

        private synchronized void set(Instant value) {
            current = value;
        }
    }
}
