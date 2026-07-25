package com.walkingrpg.backend.expedition.infrastructure;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

import com.walkingrpg.backend.expedition.domain.ExpeditionIdempotencyScope;
import com.walkingrpg.backend.expedition.domain.ExpeditionProgressState;
import com.walkingrpg.backend.expedition.domain.ProcessedExpeditionAdvance;

public class InMemoryExpeditionRepository implements ExpeditionRepository {

    private final Map<StateKey, ExpeditionProgressState> states = new HashMap<>();
    private final Map<ExpeditionIdempotencyScope, ProcessedExpeditionAdvance> processed =
            new HashMap<>();

    @Override
    public synchronized void acquireLock(String userId, String expeditionId) {
        // Test double serializes all operations through synchronized methods.
    }

    @Override
    public synchronized Optional<ExpeditionProgressState> findState(
            String userId,
            String expeditionId
    ) {
        return Optional.ofNullable(states.get(new StateKey(userId, expeditionId)));
    }

    @Override
    public synchronized void saveState(
            String userId,
            String expeditionId,
            ExpeditionProgressState state,
            Instant updatedAt
    ) {
        states.put(new StateKey(userId, expeditionId), state);
    }

    @Override
    public synchronized Optional<ProcessedExpeditionAdvance> findProcessed(
            ExpeditionIdempotencyScope scope
    ) {
        return Optional.ofNullable(processed.get(scope));
    }

    @Override
    public synchronized void saveProcessed(
            ExpeditionIdempotencyScope scope,
            ProcessedExpeditionAdvance value
    ) {
        processed.put(scope, value);
    }

    private record StateKey(String userId, String expeditionId) {
    }
}
