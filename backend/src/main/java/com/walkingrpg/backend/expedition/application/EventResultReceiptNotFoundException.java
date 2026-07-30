package com.walkingrpg.backend.expedition.application;

import java.util.UUID;

public class EventResultReceiptNotFoundException extends RuntimeException {

    private final UUID receiptId;

    public EventResultReceiptNotFoundException(UUID receiptId) {
        super("Результат события не найден: " + receiptId);
        this.receiptId = receiptId;
    }

    public UUID receiptId() {
        return receiptId;
    }
}
