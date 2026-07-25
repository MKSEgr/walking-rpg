package com.walkingrpg.backend.activity.infrastructure;

import java.time.Instant;
import java.time.ZoneId;
import java.util.Optional;

import com.walkingrpg.backend.activity.domain.ActivityDayKey;
import com.walkingrpg.backend.activity.domain.ActivityDayState;
import com.walkingrpg.backend.activity.domain.IdempotencyScope;
import com.walkingrpg.backend.activity.domain.ProcessedActivitySync;

public interface ActivitySyncRepository {

    void acquireDeviceLock(String userId, String deviceId);

    void registerDevice(String userId, String deviceId, Instant seenAt);

    Optional<ActivityDayState> findState(ActivityDayKey key);

    void saveState(ActivityDayKey key, ActivityDayState state, ZoneId timeZone);

    Optional<ProcessedActivitySync> findProcessed(IdempotencyScope scope);

    void saveProcessed(IdempotencyScope scope, ProcessedActivitySync processedSync);
}
