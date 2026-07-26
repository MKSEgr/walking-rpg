package com.walkingrpg.backend.home.application;

import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;

import com.walkingrpg.backend.expedition.application.StarterExpeditionContent;
import com.walkingrpg.backend.expedition.domain.ExpeditionDefinition;
import com.walkingrpg.backend.expedition.domain.ExpeditionEventChoiceDefinition;
import com.walkingrpg.backend.expedition.domain.ExpeditionProgressStatus;
import com.walkingrpg.backend.goal.application.DailyGoalService;
import com.walkingrpg.backend.goal.domain.DailyGoal;
import com.walkingrpg.backend.home.api.HomeSnapshotResponse;
import com.walkingrpg.backend.home.domain.DailyGoalPolicySnapshot;
import com.walkingrpg.backend.home.domain.ExpeditionEventChoiceSnapshot;
import com.walkingrpg.backend.home.domain.ExpeditionEventSnapshot;
import com.walkingrpg.backend.home.domain.ExpeditionSnapshot;
import com.walkingrpg.backend.home.domain.HomeQuery;
import com.walkingrpg.backend.home.domain.HomeRuntimeState;
import com.walkingrpg.backend.home.domain.PetSnapshot;
import com.walkingrpg.backend.home.domain.PilotSnapshot;
import com.walkingrpg.backend.home.infrastructure.HomeReadRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class HomeService {

    private final HomeReadRepository repository;
    private final StarterHomeContent starterContent;
    private final DailyGoalService dailyGoalService;
    private final StarterExpeditionContent expeditionContent;
    private final Clock clock;

    public HomeService(
            HomeReadRepository repository,
            StarterHomeContent starterContent,
            DailyGoalService dailyGoalService,
            StarterExpeditionContent expeditionContent,
            Clock clock
    ) {
        this.repository = repository;
        this.starterContent = starterContent;
        this.dailyGoalService = dailyGoalService;
        this.expeditionContent = expeditionContent;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public HomeSnapshotResponse getSnapshot(HomeQuery query) {
        ExpeditionDefinition definition = expeditionContent.definition();
        DailyGoal dailyGoal = dailyGoalService.calculate(
                query.userId(),
                query.localDate()
        );
        HomeRuntimeState state = repository.findState(
                query.userId(),
                query.localDate(),
                definition.expeditionId()
        );

        return new HomeSnapshotResponse(
                query.localDate(),
                state.timeZone(),
                state.dailySteps(),
                dailyGoal.steps(),
                DailyGoalPolicySnapshot.from(dailyGoal),
                state.availableEnergy(),
                state.activityStateVersion(),
                state.economyVersion(),
                state.lastActivitySyncAt(),
                Instant.now(clock).truncatedTo(ChronoUnit.MICROS),
                starterContent.contentVersion(),
                pilotSnapshot(state),
                petSnapshot(state),
                expeditionSnapshot(definition, state)
        );
    }

    private PilotSnapshot pilotSnapshot(HomeRuntimeState state) {
        PilotSnapshot starter = starterContent.pilot();
        if (!state.pilotProgressPresent()) {
            return starter;
        }
        return new PilotSnapshot(
                starter.name(),
                state.pilotLevel(),
                state.pilotCurrentExperience(),
                state.pilotNextLevelExperience(),
                starter.specialization()
        );
    }

    private PetSnapshot petSnapshot(HomeRuntimeState state) {
        PetSnapshot starter = starterContent.pet();
        if (!state.petProgressPresent()) {
            return starter;
        }
        return new PetSnapshot(
                starter.name(),
                starter.species(),
                state.petLevel(),
                state.petBond(),
                starter.trait()
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
                eventSnapshot(definition, state)
        );
    }

    private ExpeditionEventSnapshot eventSnapshot(
            ExpeditionDefinition definition,
            HomeRuntimeState state
    ) {
        if (state.unlockedEventId() == null) {
            return null;
        }
        List<ExpeditionEventChoiceSnapshot> choices = expeditionContent
                .eventChoices(state.unlockedEventId())
                .stream()
                .map(this::choiceSnapshot)
                .toList();
        boolean resolved = ExpeditionProgressStatus.COMPLETED.name()
                .equals(state.expeditionStatus());
        return new ExpeditionEventSnapshot(
                definition.event().eventId(),
                definition.event().title(),
                definition.event().summary(),
                resolved ? "RESOLVED" : "READY",
                choices,
                resolved ? state.resolvedChoiceId() : null,
                resolved ? state.resolvedChoiceTitle() : null,
                resolved ? state.outcomeTitle() : null,
                resolved ? state.outcomeSummary() : null
        );
    }

    private ExpeditionEventChoiceSnapshot choiceSnapshot(
            ExpeditionEventChoiceDefinition choice
    ) {
        return new ExpeditionEventChoiceSnapshot(
                choice.choiceId(),
                choice.title(),
                choice.description(),
                choice.pilotExperienceReward(),
                choice.petBondReward()
        );
    }
}
