package com.walkingrpg.backend.activity.infrastructure;

import java.time.Instant;
import java.time.ZoneId;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

import com.walkingrpg.backend.activity.domain.ActivityDayKey;
import com.walkingrpg.backend.activity.domain.ActivityDayState;
import com.walkingrpg.backend.activity.domain.IdempotencyScope;
import com.walkingrpg.backend.activity.domain.ProcessedActivitySync;

public class InMemoryActivitySyncRepository implements ActivitySyncRepository {

    private final Map<ActivityDayKey, ActivityDayState> states = new ConcurrentHashMap<>();
    private final Map<IdempotencyScope, ProcessedActivitySync> processedSyncs =
            new ConcurrentHashMap<>();
    private final Set<String> successfullySyncedUsers = ConcurrentHashMap.newKeySet();

    @Override
    public void acquireUserLock(String userId) {
        // Unit and standalone API tests execute in one process and do not need a database lock.
    }

    @Override
    public void registerDevice(String userId, String deviceId, Instant seenAt) {
        // Identity persistence is intentionally absent in the in-memory test double.
    }

    @Override
    public Optional<ActivityDayState> findState(ActivityDayKey key) {
        return Optional.ofNullable(states.get(key));
    }

    @Override
    public void saveState(ActivityDayKey key, ActivityDayState state, ZoneId timeZone) {
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

    @Override
    public void markSuccessfulSync(String userId) {
        successfullySyncedUsers.add(userId);
    }
}
