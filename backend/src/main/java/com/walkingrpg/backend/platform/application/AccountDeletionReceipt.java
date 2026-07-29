package com.walkingrpg.backend.platform.application;

import java.time.Instant;
import java.util.UUID;

public record AccountDeletionReceipt(
        UUID receiptId,
        String status,
        Instant requestedAt,
        Instant completedAt,
        boolean replayed
) {
}
