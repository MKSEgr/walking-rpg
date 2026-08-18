package com.walkingrpg.backend.home.domain;

import java.util.List;

public record ExpeditionCompletionRecapSnapshot(
        long journeyNumber,
        int decisionCount,
        long pilotExperienceGained,
        long petBondGained,
        List<MaterialRewardPreviewSnapshot> materials
) {
    public ExpeditionCompletionRecapSnapshot {
        materials = materials == null ? List.of() : List.copyOf(materials);
    }
}
