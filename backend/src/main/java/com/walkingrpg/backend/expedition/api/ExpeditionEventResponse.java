package com.walkingrpg.backend.expedition.api;

import com.walkingrpg.backend.expedition.domain.ExpeditionEventStatus;

public record ExpeditionEventResponse(
        String eventId,
        String title,
        String summary,
        ExpeditionEventStatus status
) {
}
