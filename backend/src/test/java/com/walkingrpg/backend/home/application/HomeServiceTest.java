package com.walkingrpg.backend.home.application;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;

import com.walkingrpg.backend.expedition.application.StarterExpeditionContent;
import com.walkingrpg.backend.goal.application.AdaptiveDailyGoalCalculator;
import com.walkingrpg.backend.goal.application.DailyGoalPolicyProperties;
import com.walkingrpg.backend.goal.application.DailyGoalService;
import com.walkingrpg.backend.home.api.HomeSnapshotResponse;
import com.walkingrpg.backend.home.domain.HomeQuery;
import com.walkingrpg.backend.home.domain.HomeRuntimeState;
import com.walkingrpg.backend.home.infrastructure.HomeReadRepository;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;

class HomeServiceTest {

    private static final Instant NOW = Instant.parse("2026-07-25T12:00:00Z");
    private static final Instant LAST_SYNC = Instant.parse("2026-07-25T11:55:00Z");

    @Test
    void shouldCombineRuntimeStateWithStarterContentAndEvent() {
        HomeReadRepository repository = (userId, localDate, expeditionId) ->
                new HomeRuntimeState(
                        6_842,
                        3,
                        "Europe/Berlin",
                        LAST_SYNC,
                        38,
                        2,
                        30,
                        30,
                        "EVENT_READY",
                        1,
                        "outer-beacon",
                        "signal-source-v1"
                );
        DailyGoalPolicyProperties goalProperties = goalProperties();
        HomeService service = new HomeService(
                repository,
                new StarterHomeContent(),
                new DailyGoalService(
                        (userId, fromInclusive, toExclusive) ->
                                List.of(2_000L, 3_000L, 4_000L),
                        new AdaptiveDailyGoalCalculator(goalProperties),
                        goalProperties
                ),
                new StarterExpeditionContent(),
                Clock.fixed(NOW, ZoneOffset.UTC)
        );

        HomeSnapshotResponse snapshot = service.getSnapshot(
                new HomeQuery("user-1", LocalDate.of(2026, 7, 25))
        );

        assertEquals(6_842, snapshot.dailySteps());
        assertEquals(3_250, snapshot.dailyGoal());
        assertEquals("ADAPTIVE", snapshot.dailyGoalPolicy().source().name());
        assertEquals(BigDecimal.valueOf(3_000), snapshot.dailyGoalPolicy().baselineSteps());
        assertEquals(3, snapshot.dailyGoalPolicy().sampleDays());
        assertEquals(6_000, snapshot.dailyGoalPolicy().defaultGoal());
        assertEquals(38, snapshot.availableEnergy());
        assertEquals(3, snapshot.activityStateVersion());
        assertEquals(2, snapshot.economyVersion());
        assertEquals("Europe/Berlin", snapshot.timeZone());
        assertEquals(LAST_SYNC, snapshot.lastActivitySyncAt());
        assertEquals(NOW, snapshot.serverTime());
        assertEquals("Навигатор", snapshot.pilot().name());
        assertEquals("Искра", snapshot.pet().name());
        assertEquals("starter-expedition-v1", snapshot.expedition().expeditionId());
        assertEquals(30, snapshot.expedition().progress());
        assertEquals("EVENT_READY", snapshot.expedition().status());
        assertNotNull(snapshot.expedition().unlockedEvent());
    }

    private DailyGoalPolicyProperties goalProperties() {
        return new DailyGoalPolicyProperties(
                "adaptive-median-v1",
                7,
                3,
                6_000,
                2_000,
                12_000,
                5,
                250
        );
    }
}
