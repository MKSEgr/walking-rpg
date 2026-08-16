package com.walkingrpg.backend.home.domain;

public record ExpeditionChoiceRequirementSnapshot(
        String type,
        String slotId,
        String slotName,
        String itemId,
        String itemName,
        long minimumUpgradeLevel,
        int minimumEvolutionStage,
        String description
) {
}
