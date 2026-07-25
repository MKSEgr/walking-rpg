package com.walkingrpg.backend.activity.domain;

import java.time.Instant;

public record ActivityBucket(
        Instant from,
        Instant to,
        long steps
) {
}
