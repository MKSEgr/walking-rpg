package com.walkingrpg.backend.home.api;

import com.walkingrpg.backend.home.domain.ExpeditionSnapshot;
import com.walkingrpg.backend.home.domain.PetSnapshot;
import com.walkingrpg.backend.home.domain.PilotSnapshot;

public record HomeSnapshotResponse(
        int dailySteps,
        int dailyGoal,
        int availableEnergy,
        PilotSnapshot pilot,
        PetSnapshot pet,
        ExpeditionSnapshot expedition
) {
}
