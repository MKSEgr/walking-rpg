package com.walkingrpg.backend.expedition.api;

import java.time.Instant;
import java.util.UUID;

public record EventResultAcknowledgementResponse(
        UUID receiptId,
        String eventId,
        String status,
        Instant acknowledgedAt,
        Instant serverTime
) {
}
