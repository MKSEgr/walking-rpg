package com.walkingrpg.backend.expedition.domain;

import java.time.Instant;

public record ExpeditionJourneyStartResult(
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
