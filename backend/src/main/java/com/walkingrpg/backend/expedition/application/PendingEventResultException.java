package com.walkingrpg.backend.expedition.application;

import java.util.UUID;

public class PendingEventResultException extends RuntimeException {

    private final UUID receiptId;
    private final String eventId;

    public PendingEventResultException(UUID receiptId, String eventId) {
        super("Сначала подтвердите предыдущий результат события");
        this.receiptId = receiptId;
        this.eventId = eventId;
    }

    public UUID receiptId() {
        return receiptId;
    }

    public String eventId() {
        return eventId;
    }
}
