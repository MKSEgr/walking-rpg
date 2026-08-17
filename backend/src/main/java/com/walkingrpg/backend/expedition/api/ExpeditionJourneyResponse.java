package com.walkingrpg.backend.expedition.api;

import java.time.Instant;

import com.walkingrpg.backend.expedition.domain.ExpeditionProgressStatus;

public record ExpeditionJourneyResponse(
        String contentVersion,
        String expeditionId,
        String expeditionName,
        long journeyNumber,
        long progressAfter,
        long requiredEnergy,
        long expeditionVersion,
        ExpeditionProgressStatus status,
        String currentNodeId,
        String currentNodeName,
        Instant serverTime
) {
}
