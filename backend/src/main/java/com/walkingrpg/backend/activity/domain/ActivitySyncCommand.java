package com.walkingrpg.backend.activity.domain;

import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;

public record ActivitySyncCommand(
        String userId,
        String deviceId,
        LocalDate localDate,
        ZoneId timeZone,
        long authoritativeTotal,
        List<ActivityBucket> buckets,
        String syncCursor,
        String idempotencyKey,
        String attestation
) {
    public ActivitySyncCommand {
        buckets = List.copyOf(buckets);
    }
}
