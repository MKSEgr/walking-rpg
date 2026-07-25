package com.walkingrpg.backend.activity.infrastructure;

import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

import com.walkingrpg.backend.activity.domain.ActivityDayKey;
import com.walkingrpg.backend.activity.domain.ActivityDayState;
import com.walkingrpg.backend.activity.domain.IdempotencyScope;
import com.walkingrpg.backend.activity.domain.ProcessedActivitySync;
import org.springframework.stereotype.Repository;

@Repository
public class InMemoryActivitySyncRepository implements ActivitySyncRepository {

    private final Map<ActivityDayKey, ActivityDayState> states = new ConcurrentHashMap<>();
    private final Map<IdempotencyScope, ProcessedActivitySync> processedSyncs =
            new ConcurrentHashMap<>();

    @Override
    public Optional<ActivityDayState> findState(ActivityDayKey key) {
        return Optional.ofNullable(states.get(key));
    }

    @Override
    public void saveState(ActivityDayKey key, ActivityDayState state) {
        states.put(key, state);
    }

    @Override
    public Optional<ProcessedActivitySync> findProcessed(IdempotencyScope scope) {
        return Optional.ofNullable(processedSyncs.get(scope));
    }

    @Override
    public void saveProcessed(
            IdempotencyScope scope,
            ProcessedActivitySync processedSync
    ) {
        processedSyncs.put(scope, processedSync);
    }
}
