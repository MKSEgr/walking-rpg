package com.walkingrpg.backend.expedition.application;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.Optional;
import java.util.UUID;
import java.util.function.Supplier;

import com.walkingrpg.backend.expedition.domain.EventResultAcknowledgementResult;
import com.walkingrpg.backend.expedition.infrastructure.InMemoryEventResolutionRepository;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

class EventResultAcknowledgementServiceTest {

    private static final Instant LOCK_TIME =
            Instant.parse("2026-07-26T12:00:00Z");
    private static final UUID RECEIPT_ID = UUID.fromString(
            "11111111-2222-3333-4444-555555555555"
    );

    @Test
    void shouldTimestampAcknowledgementAfterAccountLock() {
        MutableClock clock = new MutableClock(LOCK_TIME.minusSeconds(30));
        InMemoryEventResolutionRepository repository =
                new InMemoryEventResolutionRepository() {
                    @Override
                    public Optional<EventResultAcknowledgementResult>
                            acknowledgeResult(
                                    String userId,
                                    UUID receiptId,
                                    Supplier<Instant> serverTimeSupplier
                            ) {
                        clock.set(LOCK_TIME);
                        Instant serverTime = serverTimeSupplier.get();
                        return Optional.of(new EventResultAcknowledgementResult(
                                receiptId,
                                "signal-source-v1",
                                serverTime,
                                serverTime
                        ));
                    }
                };
        EventResultAcknowledgementService service =
                new EventResultAcknowledgementService(repository, clock);

        EventResultAcknowledgementResult result = service.acknowledge(
                "ack-lock-time-user",
                RECEIPT_ID
        );

        assertEquals(LOCK_TIME, result.acknowledgedAt());
        assertEquals(LOCK_TIME, result.serverTime());
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
