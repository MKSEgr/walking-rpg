package com.walkingrpg.backend.platform.payment;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.UUID;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

@Component
@Profile({"local", "test"})
@ConditionalOnProperty(
        prefix = "walking-rpg.providers",
        name = "payment",
        havingValue = "sandbox"
)
public class SandboxPaymentProvider implements PaymentProvider {

    @Override
    public boolean isAvailable() {
        return true;
    }

    @Override
    public PaymentReceipt purchase(
            String userId,
            String productId,
            long amountMinor,
            String idempotencyKey,
            Instant occurredAt
    ) {
        if (amountMinor <= 0) {
            throw new IllegalArgumentException("Сумма sandbox-покупки должна быть положительной");
        }
        String reference = UUID.nameUUIDFromBytes(
                (userId + ":" + productId + ":" + idempotencyKey)
                        .getBytes(StandardCharsets.UTF_8)
        ).toString();
        return new PaymentReceipt("SANDBOX", reference, "SUCCEEDED", occurredAt);
    }
}
