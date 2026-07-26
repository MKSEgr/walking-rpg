package com.walkingrpg.backend.expedition.api;

import java.time.Instant;

import com.walkingrpg.backend.expedition.domain.EventResolutionStatus;
import com.walkingrpg.backend.expedition.domain.ExpeditionProgressStatus;

public record EventResolutionResponse(
        String contentVersion,
        String expeditionId,
        ExpeditionProgressStatus expeditionStatus,
        long expeditionVersion,
        String eventId,
        String eventTitle,
        EventResolutionStatus status,
        String choiceId,
        String choiceTitle,
        String outcomeTitle,
        String outcomeSummary,
        EventPilotRewardResponse pilot,
        EventPetRewardResponse pet,
        EventMaterialRewardResponse material,
        Instant serverTime
) {
}
