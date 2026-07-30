package com.walkingrpg.backend.platform.payment;

import java.time.Instant;

import com.walkingrpg.backend.platform.application.PlatformStateConflictException;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnProperty(
        prefix = "walking-rpg.providers",
        name = "payment",
        havingValue = "disabled",
        matchIfMissing = true
)
public class DisabledPaymentProvider implements PaymentProvider {

    @Override
    public boolean isAvailable() {
        return false;
    }

    @Override
    public PaymentReceipt purchase(
            String userId,
            String productId,
            long amountMinor,
            String idempotencyKey,
            Instant occurredAt
    ) {
        throw new PlatformStateConflictException(
                "Покупки недоступны в текущей конфигурации"
        );
    }
}
