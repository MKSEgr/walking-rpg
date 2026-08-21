package com.walkingrpg.backend.home.application;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;

import com.walkingrpg.backend.expedition.application.StarterExpeditionContent;
import com.walkingrpg.backend.goal.application.AdaptiveDailyGoalCalculator;
import com.walkingrpg.backend.goal.application.DailyGoalPolicyProperties;
import com.walkingrpg.backend.home.api.HomeSnapshotResponse;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;

class DemoHomeServiceTest {

    private static final Instant NOW = Instant.parse("2026-07-25T12:00:00Z");

    private final DemoHomeService service = new DemoHomeService(
            new StarterHomeContent(),
            new StarterExpeditionContent(),
            new AdaptiveDailyGoalCalculator(new DailyGoalPolicyProperties(
                    "adaptive-median-v1",
                    7,
                    3,
                    6_000,
                    2_000,
                    12_000,
                    5,
                    250
            )),
            Clock.fixed(NOW, ZoneOffset.UTC)
    );

    @Test
    void shouldReturnConsistentInitialSnapshot() {
        HomeSnapshotResponse snapshot = service.getDemoSnapshot();

        assertEquals("2026-07-25", snapshot.localDate().toString());
        assertEquals("UTC", snapshot.timeZone());
        assertEquals(0, snapshot.dailySteps());
        assertEquals(6_000, snapshot.dailyGoal());
        assertEquals("DEFAULT", snapshot.dailyGoalPolicy().source().name());
        assertEquals(0, snapshot.dailyGoalPolicy().sampleDays());
        assertEquals(0, snapshot.weeklyActivityRhythm().activeDays());
        assertEquals(7, snapshot.weeklyActivityRhythm().windowDays());
        assertEquals(4, snapshot.weeklyActivityRhythm().targetActiveDays());
        assertEquals(false, snapshot.weeklyActivityRhythm().targetReached());
        assertEquals(0, snapshot.availableEnergy());
        assertEquals(0, snapshot.activityStateVersion());
        assertEquals(0, snapshot.economyVersion());
        assertNull(snapshot.lastActivitySyncAt());
        assertEquals(NOW, snapshot.serverTime());
        assertEquals(
                StarterExpeditionContent
                        .STEADY_STEP_ROUTE_CONTENT_VERSION,
                snapshot.contentVersion()
        );
        assertNotNull(snapshot.pilot());
        assertNotNull(snapshot.pet());
        assertNotNull(snapshot.expedition());
        assertEquals("starter-expedition-v1", snapshot.expedition().expeditionId());
        assertEquals(30, snapshot.expedition().requiredEnergy());
        assertEquals("IN_PROGRESS", snapshot.expedition().status());
        assertEquals(1, snapshot.expedition().routeTrail().size());
        assertEquals("CURRENT",
                snapshot.expedition().routeTrail().getFirst().state());
        assertEquals(0, snapshot.expedition().decisionLog().size());
        assertNull(snapshot.expedition().unlockedEvent());
    }
}
