package com.walkingrpg.backend.platform.payment;

import java.time.Instant;

public interface PaymentProvider {

    boolean isAvailable();

    PaymentReceipt purchase(
            String userId,
            String productId,
            long amountMinor,
            String idempotencyKey,
            Instant occurredAt
    );
}
