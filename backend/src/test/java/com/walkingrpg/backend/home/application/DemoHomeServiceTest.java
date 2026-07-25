package com.walkingrpg.backend.home.application;

import com.walkingrpg.backend.home.api.HomeSnapshotResponse;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;

class DemoHomeServiceTest {

    private final DemoHomeService service = new DemoHomeService();

    @Test
    void shouldReturnConsistentInitialSnapshot() {
        HomeSnapshotResponse snapshot = service.getDemoSnapshot();

        assertEquals(0, snapshot.dailySteps());
        assertEquals(6_000, snapshot.dailyGoal());
        assertEquals(0, snapshot.availableEnergy());
        assertNotNull(snapshot.pilot());
        assertNotNull(snapshot.pet());
        assertNotNull(snapshot.expedition());
        assertEquals(30, snapshot.expedition().requiredEnergy());
    }
}
