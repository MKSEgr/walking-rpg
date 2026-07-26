package com.walkingrpg.backend.expedition.domain;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;

class EventResolutionFingerprintTest {

    @Test
    void shouldIgnoreUserAndIdempotencyKeyButIncludeChoice() {
        String first = EventResolutionFingerprint.sha256(new EventResolutionCommand(
                "user-a",
                "signal-source-v1",
                "analyze-signal",
                "key-a"
        ));
        String replay = EventResolutionFingerprint.sha256(new EventResolutionCommand(
                "user-b",
                "signal-source-v1",
                "analyze-signal",
                "key-b"
        ));
        String changedChoice = EventResolutionFingerprint.sha256(new EventResolutionCommand(
                "user-a",
                "signal-source-v1",
                "trust-spark",
                "key-a"
        ));

        assertEquals(first, replay);
        assertNotEquals(first, changedChoice);
        assertEquals(64, first.length());
    }
}
