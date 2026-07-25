package com.walkingrpg.backend.home.domain;

public record ExpeditionSnapshot(
        String expeditionId,
        String name,
        String currentNodeId,
        String currentNode,
        long progress,
        long requiredEnergy,
        String status,
        long version,
        ExpeditionEventSnapshot unlockedEvent
) {
}
