package com.walkingrpg.backend.home.application;

import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;

import com.walkingrpg.backend.home.api.HomeSnapshotResponse;
import com.walkingrpg.backend.home.domain.HomeQuery;
import com.walkingrpg.backend.home.domain.HomeRuntimeState;
import com.walkingrpg.backend.home.infrastructure.HomeReadRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class HomeService {

    private final HomeReadRepository repository;
    private final StarterHomeContent starterContent;
    private final Clock clock;

    public HomeService(
            HomeReadRepository repository,
            StarterHomeContent starterContent,
            Clock clock
    ) {
        this.repository = repository;
        this.starterContent = starterContent;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public HomeSnapshotResponse getSnapshot(HomeQuery query) {
        HomeRuntimeState state = repository.findState(
                query.userId(),
                query.localDate()
        );

        return new HomeSnapshotResponse(
                query.localDate(),
                state.timeZone(),
                state.dailySteps(),
                starterContent.dailyGoal(),
                state.availableEnergy(),
                state.activityStateVersion(),
                state.economyVersion(),
                state.lastActivitySyncAt(),
                Instant.now(clock).truncatedTo(ChronoUnit.MICROS),
                starterContent.contentVersion(),
                starterContent.pilot(),
                starterContent.pet(),
                starterContent.expedition()
        );
    }
}
