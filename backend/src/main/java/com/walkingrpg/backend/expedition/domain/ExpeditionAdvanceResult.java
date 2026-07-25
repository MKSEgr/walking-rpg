package com.walkingrpg.backend.expedition.domain;

import java.time.Instant;

public record ExpeditionAdvanceResult(
        String contentVersion,
        String expeditionId,
        String expeditionName,
        long energySpent,
        long energyBalanceAfter,
        long economyVersion,
        long progressAfter,
        long requiredEnergy,
        long expeditionVersion,
        ExpeditionProgressStatus status,
        String currentNodeId,
        String currentNodeName,
        ExpeditionEventDefinition unlockedEvent,
        Instant serverTime
) {
}
