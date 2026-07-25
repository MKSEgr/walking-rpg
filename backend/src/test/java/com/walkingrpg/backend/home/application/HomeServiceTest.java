package com.walkingrpg.backend.home.application;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;

import com.walkingrpg.backend.home.api.HomeSnapshotResponse;
import com.walkingrpg.backend.home.domain.HomeQuery;
import com.walkingrpg.backend.home.domain.HomeRuntimeState;
import com.walkingrpg.backend.home.infrastructure.HomeReadRepository;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

class HomeServiceTest {

    private static final Instant NOW = Instant.parse("2026-07-25T12:00:00Z");
    private static final Instant LAST_SYNC = Instant.parse("2026-07-25T11:55:00Z");

    @Test
    void shouldCombineRuntimeStateWithStarterContent() {
        HomeReadRepository repository = (userId, localDate) -> new HomeRuntimeState(
                6_842,
                3,
                "Europe/Berlin",
                LAST_SYNC,
                68,
                2
        );
        HomeService service = new HomeService(
                repository,
                new StarterHomeContent(),
                Clock.fixed(NOW, ZoneOffset.UTC)
        );

        HomeSnapshotResponse snapshot = service.getSnapshot(
                new HomeQuery("user-1", LocalDate.of(2026, 7, 25))
        );

        assertEquals(6_842, snapshot.dailySteps());
        assertEquals(6_000, snapshot.dailyGoal());
        assertEquals(68, snapshot.availableEnergy());
        assertEquals(3, snapshot.activityStateVersion());
        assertEquals(2, snapshot.economyVersion());
        assertEquals("Europe/Berlin", snapshot.timeZone());
        assertEquals(LAST_SYNC, snapshot.lastActivitySyncAt());
        assertEquals(NOW, snapshot.serverTime());
        assertEquals("Навигатор", snapshot.pilot().name());
        assertEquals("Искра", snapshot.pet().name());
        assertEquals("Сигнал из туманного сектора", snapshot.expedition().name());
    }
}
