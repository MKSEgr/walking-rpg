package com.walkingrpg.backend.platform.payment;

import java.time.Instant;

public record PaymentReceipt(
        String provider,
        String reference,
        String status,
        Instant processedAt
) {
}
