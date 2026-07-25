package com.walkingrpg.backend.activity.domain;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;

class ActivitySyncFingerprintTest {

    @Test
    void shouldBeStableForTheSameCommand() {
        ActivitySyncCommand command = command(1_000, List.of());

        assertEquals(
                ActivitySyncFingerprint.sha256(command),
                ActivitySyncFingerprint.sha256(command)
        );
    }

    @Test
    void shouldChangeWhenBucketPayloadChanges() {
        ActivitySyncCommand withoutBuckets = command(1_000, List.of());
        ActivitySyncCommand withBucket = command(
                1_000,
                List.of(new ActivityBucket(
                        Instant.parse("2026-07-25T10:00:00Z"),
                        Instant.parse("2026-07-25T11:00:00Z"),
                        1_000
                ))
        );

        assertNotEquals(
                ActivitySyncFingerprint.sha256(withoutBuckets),
                ActivitySyncFingerprint.sha256(withBucket)
        );
    }

    @Test
    void shouldIgnoreAttestationRotation() {
        ActivitySyncCommand first = command(1_000, List.of(), "attestation-a");
        ActivitySyncCommand retried = command(1_000, List.of(), "attestation-b");

        assertEquals(
                ActivitySyncFingerprint.sha256(first),
                ActivitySyncFingerprint.sha256(retried)
        );
    }

    private ActivitySyncCommand command(long total, List<ActivityBucket> buckets) {
        return command(total, buckets, null);
    }

    private ActivitySyncCommand command(
            long total,
            List<ActivityBucket> buckets,
            String attestation
    ) {
        return new ActivitySyncCommand(
                "user-1",
                "device-1",
                LocalDate.of(2026, 7, 25),
                ZoneId.of("Europe/Berlin"),
                total,
                buckets,
                "cursor-1",
                "sync-1",
                attestation
        );
    }
}
