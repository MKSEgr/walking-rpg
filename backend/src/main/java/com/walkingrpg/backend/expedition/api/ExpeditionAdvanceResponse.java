package com.walkingrpg.backend.expedition.api;

import java.time.Instant;

import com.walkingrpg.backend.expedition.domain.ExpeditionProgressStatus;

public record ExpeditionAdvanceResponse(
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
        ExpeditionEventResponse unlockedEvent,
        Instant serverTime
) {
}
