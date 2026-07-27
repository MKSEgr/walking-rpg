package com.walkingrpg.backend.activity.retention;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

class ActivityRetentionServiceTest {

    @Test
    void shouldDeleteProcessedCommandsBeforeConfiguredCutoff() {
        Instant now = Instant.parse("2026-07-27T08:30:00Z");
        CapturingRepository repository = new CapturingRepository(7);
        ActivityRetentionService service = new ActivityRetentionService(
                repository,
                new ActivityRetentionProperties(30),
                Clock.fixed(now, ZoneOffset.UTC)
        );

        int deleted = service.cleanup();

        assertEquals(7, deleted);
        assertEquals(Instant.parse("2026-06-27T08:30:00Z"), repository.cutoff);
    }

    @Test
    void shouldUseThirtyDaysWhenConfiguredValueIsInvalid() {
        ActivityRetentionProperties properties = new ActivityRetentionProperties(0);

        assertEquals(30, properties.days());
    }

    private static final class CapturingRepository implements ActivityRetentionRepository {
        private final int result;
        private Instant cutoff;

        private CapturingRepository(int result) {
            this.result = result;
        }

        @Override
        public int deleteProcessedBefore(Instant value) {
            cutoff = value;
            return result;
        }
    }
}
