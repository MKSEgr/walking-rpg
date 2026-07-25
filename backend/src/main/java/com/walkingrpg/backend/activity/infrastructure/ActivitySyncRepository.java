package com.walkingrpg.backend.activity.infrastructure;

import java.util.Optional;

import com.walkingrpg.backend.activity.domain.ActivityDayKey;
import com.walkingrpg.backend.activity.domain.ActivityDayState;
import com.walkingrpg.backend.activity.domain.IdempotencyScope;
import com.walkingrpg.backend.activity.domain.ProcessedActivitySync;

public interface ActivitySyncRepository {

    Optional<ActivityDayState> findState(ActivityDayKey key);

    void saveState(ActivityDayKey key, ActivityDayState state);

    Optional<ProcessedActivitySync> findProcessed(IdempotencyScope scope);

    void saveProcessed(IdempotencyScope scope, ProcessedActivitySync processedSync);
}
