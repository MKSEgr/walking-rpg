package com.walkingrpg.backend.platform.push;

public record PushDeliveryResult(
        String provider,
        boolean accepted,
        String reference
) {
}
