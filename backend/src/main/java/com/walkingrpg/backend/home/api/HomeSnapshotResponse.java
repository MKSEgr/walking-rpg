package com.walkingrpg.backend.home.api;

import java.time.Instant;
import java.time.LocalDate;

import com.walkingrpg.backend.home.domain.DailyGoalPolicySnapshot;
import com.walkingrpg.backend.home.domain.ExpeditionSnapshot;
import com.walkingrpg.backend.home.domain.PetSnapshot;
import com.walkingrpg.backend.home.domain.PilotSnapshot;

public record HomeSnapshotResponse(
        LocalDate localDate,
        String timeZone,
        long dailySteps,
        long dailyGoal,
        DailyGoalPolicySnapshot dailyGoalPolicy,
        long availableEnergy,
        long activityStateVersion,
        long economyVersion,
        Instant lastActivitySyncAt,
        Instant serverTime,
        String contentVersion,
        PilotSnapshot pilot,
        PetSnapshot pet,
        ExpeditionSnapshot expedition
) {
}
