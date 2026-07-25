package com.walkingrpg.backend.expedition.domain;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;

class ExpeditionAdvanceFingerprintTest {

    @Test
    void shouldDependOnExpeditionAndEnergyButNotUserOrKey() {
        ExpeditionAdvanceCommand first = new ExpeditionAdvanceCommand(
                "user-a",
                "starter-expedition-v1",
                10,
                "key-a"
        );
        ExpeditionAdvanceCommand sameBusinessPayload = new ExpeditionAdvanceCommand(
                "user-b",
                "starter-expedition-v1",
                10,
                "key-b"
        );
        ExpeditionAdvanceCommand differentAmount = new ExpeditionAdvanceCommand(
                "user-a",
                "starter-expedition-v1",
                11,
                "key-a"
        );

        assertEquals(
                ExpeditionAdvanceFingerprint.sha256(first),
                ExpeditionAdvanceFingerprint.sha256(sameBusinessPayload)
        );
        assertNotEquals(
                ExpeditionAdvanceFingerprint.sha256(first),
                ExpeditionAdvanceFingerprint.sha256(differentAmount)
        );
    }
}
