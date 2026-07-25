package com.walkingrpg.backend.home.application;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;

import com.walkingrpg.backend.home.api.HomeSnapshotResponse;
import org.springframework.stereotype.Service;

@Service
public class DemoHomeService {

    private final StarterHomeContent starterContent;
    private final Clock clock;

    public DemoHomeService(StarterHomeContent starterContent, Clock clock) {
        this.starterContent = starterContent;
        this.clock = clock;
    }

    public HomeSnapshotResponse getDemoSnapshot() {
        Instant serverTime = Instant.now(clock).truncatedTo(ChronoUnit.MICROS);

        return new HomeSnapshotResponse(
                LocalDate.ofInstant(serverTime, ZoneOffset.UTC),
                "UTC",
                0,
                starterContent.dailyGoal(),
                0,
                0,
                0,
                null,
                serverTime,
                starterContent.contentVersion(),
                starterContent.pilot(),
                starterContent.pet(),
                starterContent.expedition()
        );
    }
}
