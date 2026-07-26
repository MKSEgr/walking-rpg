package com.walkingrpg.backend.expedition.domain;

import java.time.Instant;
import java.util.Objects;

public record EventResolutionResult(
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
        EventPilotRewardResult pilot,
        EventPetRewardResult pet,
        Instant serverTime
) {
    public EventResolutionResult {
        Objects.requireNonNull(expeditionStatus, "expeditionStatus");
        Objects.requireNonNull(status, "status");
        Objects.requireNonNull(pilot, "pilot");
        Objects.requireNonNull(pet, "pet");
        Objects.requireNonNull(serverTime, "serverTime");
    }
}
