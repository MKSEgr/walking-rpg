package com.walkingrpg.backend.home.application;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.List;

import com.walkingrpg.backend.expedition.application.StarterExpeditionContent;
import com.walkingrpg.backend.expedition.domain.ExpeditionDefinition;
import com.walkingrpg.backend.expedition.domain.ExpeditionProgressStatus;
import com.walkingrpg.backend.goal.application.AdaptiveDailyGoalCalculator;
import com.walkingrpg.backend.goal.domain.DailyGoal;
import com.walkingrpg.backend.home.api.HomeSnapshotResponse;
import com.walkingrpg.backend.home.domain.DailyGoalPolicySnapshot;
import com.walkingrpg.backend.home.domain.ExpeditionSnapshot;
import org.springframework.stereotype.Service;

@Service
public class DemoHomeService {

    private final StarterHomeContent starterContent;
    private final StarterExpeditionContent expeditionContent;
    private final AdaptiveDailyGoalCalculator dailyGoalCalculator;
    private final Clock clock;

    public DemoHomeService(
            StarterHomeContent starterContent,
            StarterExpeditionContent expeditionContent,
            AdaptiveDailyGoalCalculator dailyGoalCalculator,
            Clock clock
    ) {
        this.starterContent = starterContent;
        this.expeditionContent = expeditionContent;
        this.dailyGoalCalculator = dailyGoalCalculator;
        this.clock = clock;
    }

    public HomeSnapshotResponse getDemoSnapshot() {
        Instant serverTime = Instant.now(clock).truncatedTo(ChronoUnit.MICROS);
        ExpeditionDefinition definition = expeditionContent.definition();
        DailyGoal dailyGoal = dailyGoalCalculator.calculate(List.of());

        return new HomeSnapshotResponse(
                LocalDate.ofInstant(serverTime, ZoneOffset.UTC),
                "UTC",
                0,
                dailyGoal.steps(),
                DailyGoalPolicySnapshot.from(dailyGoal),
                0,
                0,
                0,
                null,
                serverTime,
                starterContent.contentVersion(),
                starterContent.pilot(),
                starterContent.pet(),
                new ExpeditionSnapshot(
                        definition.expeditionId(),
                        definition.name(),
                        definition.currentNodeId(),
                        definition.currentNodeName(),
                        0,
                        definition.requiredEnergy(),
                        ExpeditionProgressStatus.IN_PROGRESS.name(),
                        0,
                        null
                )
        );
    }
}
