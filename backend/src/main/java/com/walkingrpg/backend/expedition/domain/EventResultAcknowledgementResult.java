package com.walkingrpg.backend.expedition.domain;

import java.time.Instant;
import java.util.Objects;
import java.util.UUID;

public record EventResultAcknowledgementResult(
        UUID receiptId,
        String eventId,
        Instant acknowledgedAt,
        Instant serverTime
) {
    public EventResultAcknowledgementResult {
        Objects.requireNonNull(receiptId, "receiptId");
        Objects.requireNonNull(acknowledgedAt, "acknowledgedAt");
        Objects.requireNonNull(serverTime, "serverTime");
        if (eventId == null || eventId.isBlank()) {
            throw new IllegalArgumentException("eventId обязателен");
        }
    }
}
