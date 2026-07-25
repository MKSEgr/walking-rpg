package com.walkingrpg.backend.home.application;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;

import com.walkingrpg.backend.home.api.HomeSnapshotResponse;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;

class DemoHomeServiceTest {

    private static final Instant NOW = Instant.parse("2026-07-25T12:00:00Z");

    private final DemoHomeService service = new DemoHomeService(
            new StarterHomeContent(),
            Clock.fixed(NOW, ZoneOffset.UTC)
    );

    @Test
    void shouldReturnConsistentInitialSnapshot() {
        HomeSnapshotResponse snapshot = service.getDemoSnapshot();

        assertEquals("2026-07-25", snapshot.localDate().toString());
        assertEquals("UTC", snapshot.timeZone());
        assertEquals(0, snapshot.dailySteps());
        assertEquals(6_000, snapshot.dailyGoal());
        assertEquals(0, snapshot.availableEnergy());
        assertEquals(0, snapshot.activityStateVersion());
        assertEquals(0, snapshot.economyVersion());
        assertNull(snapshot.lastActivitySyncAt());
        assertEquals(NOW, snapshot.serverTime());
        assertEquals("starter-v1", snapshot.contentVersion());
        assertNotNull(snapshot.pilot());
        assertNotNull(snapshot.pet());
        assertNotNull(snapshot.expedition());
        assertEquals(30, snapshot.expedition().requiredEnergy());
    }
}
