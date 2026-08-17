package com.walkingrpg.backend.home.domain;

import java.util.List;

public record ExpeditionSnapshot(
        String expeditionId,
        String name,
        String currentNodeId,
        String currentNode,
        long progress,
        long requiredEnergy,
        String status,
        long version,
        long journeyNumber,
        List<ExpeditionRouteNodeSnapshot> routeTrail,
        List<ExpeditionDecisionSnapshot> decisionLog,
        ExpeditionEventSnapshot unlockedEvent
) {
    public ExpeditionSnapshot {
        routeTrail = routeTrail == null ? List.of() : List.copyOf(routeTrail);
        decisionLog = decisionLog == null
                ? List.of()
                : List.copyOf(decisionLog);
    }

    public ExpeditionSnapshot(
            String expeditionId,
            String name,
            String currentNodeId,
            String currentNode,
            long progress,
            long requiredEnergy,
            String status,
            long version,
            long journeyNumber,
            List<ExpeditionRouteNodeSnapshot> routeTrail,
            ExpeditionEventSnapshot unlockedEvent
    ) {
        this(
                expeditionId,
                name,
                currentNodeId,
                currentNode,
                progress,
                requiredEnergy,
                status,
                version,
                journeyNumber,
                routeTrail,
                List.of(),
                unlockedEvent
        );
    }

    public ExpeditionSnapshot(
            String expeditionId,
            String name,
            String currentNodeId,
            String currentNode,
            long progress,
            long requiredEnergy,
            String status,
            long version,
            long journeyNumber,
            ExpeditionEventSnapshot unlockedEvent
    ) {
        this(
                expeditionId,
                name,
                currentNodeId,
                currentNode,
                progress,
                requiredEnergy,
                status,
                version,
                journeyNumber,
                List.of(),
                List.of(),
                unlockedEvent
        );
    }

    public ExpeditionSnapshot(
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
        this(
                expeditionId,
                name,
                currentNodeId,
                currentNode,
                progress,
                requiredEnergy,
                status,
                version,
                1,
                List.of(),
                List.of(),
                unlockedEvent
        );
    }
}
