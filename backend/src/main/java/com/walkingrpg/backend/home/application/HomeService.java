package com.walkingrpg.backend.home.application;

import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;

import com.walkingrpg.backend.expedition.application.StarterExpeditionContent;
import com.walkingrpg.backend.expedition.domain.ExpeditionDefinition;
import com.walkingrpg.backend.expedition.domain.ExpeditionProgressStatus;
import com.walkingrpg.backend.home.api.HomeSnapshotResponse;
import com.walkingrpg.backend.home.domain.ExpeditionEventSnapshot;
import com.walkingrpg.backend.home.domain.ExpeditionSnapshot;
import com.walkingrpg.backend.home.domain.HomeQuery;
import com.walkingrpg.backend.home.domain.HomeRuntimeState;
import com.walkingrpg.backend.home.infrastructure.HomeReadRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class HomeService {

    private final HomeReadRepository repository;
    private final StarterHomeContent starterContent;
    private final StarterExpeditionContent expeditionContent;
    private final Clock clock;

    public HomeService(
            HomeReadRepository repository,
            StarterHomeContent starterContent,
            StarterExpeditionContent expeditionContent,
            Clock clock
    ) {
        this.repository = repository;
        this.starterContent = starterContent;
        this.expeditionContent = expeditionContent;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public HomeSnapshotResponse getSnapshot(HomeQuery query) {
        ExpeditionDefinition definition = expeditionContent.definition();
        HomeRuntimeState state = repository.findState(
                query.userId(),
                query.localDate(),
                definition.expeditionId()
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
                expeditionSnapshot(definition, state)
        );
    }

    private ExpeditionSnapshot expeditionSnapshot(
            ExpeditionDefinition definition,
            HomeRuntimeState state
    ) {
        long requiredEnergy = state.expeditionRequiredEnergy() > 0
                ? state.expeditionRequiredEnergy()
                : definition.requiredEnergy();
        String status = state.expeditionStatus() == null
                ? ExpeditionProgressStatus.IN_PROGRESS.name()
                : state.expeditionStatus();
        ExpeditionEventSnapshot event = state.unlockedEventId() == null
                ? null
                : new ExpeditionEventSnapshot(
                        definition.event().eventId(),
                        definition.event().title(),
                        definition.event().summary(),
                        "READY"
                );

        return new ExpeditionSnapshot(
                definition.expeditionId(),
                definition.name(),
                state.currentNodeId() == null
                        ? definition.currentNodeId()
                        : state.currentNodeId(),
                definition.currentNodeName(),
                state.expeditionProgress(),
                requiredEnergy,
                status,
                state.expeditionVersion(),
                event
        );
    }
}
