package com.walkingrpg.backend.home.domain;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

import com.walkingrpg.backend.expedition.domain.EventMaterialRewardResult;
import com.walkingrpg.backend.expedition.domain.EventNextNodeResult;
import com.walkingrpg.backend.expedition.domain.EventPetRewardResult;
import com.walkingrpg.backend.expedition.domain.EventPilotRewardResult;

public record PendingEventResultSnapshot(
        UUID receiptId,
        String eventId,
        String eventTitle,
        String choiceId,
        String choiceTitle,
        String outcomeTitle,
        String outcomeSummary,
        EventPilotRewardResult pilot,
        EventPetRewardResult pet,
        EventMaterialRewardResult material,
        EventNextNodeResult nextNode,
        Instant resolvedAt
) {
    public PendingEventResultSnapshot {
        Objects.requireNonNull(receiptId, "receiptId");
        Objects.requireNonNull(pilot, "pilot");
        Objects.requireNonNull(pet, "pet");
        Objects.requireNonNull(resolvedAt, "resolvedAt");
    }
}
