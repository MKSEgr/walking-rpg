package com.walkingrpg.backend.expedition.infrastructure;

import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

import com.walkingrpg.backend.expedition.domain.EventIdempotencyScope;
import com.walkingrpg.backend.expedition.domain.ProcessedEventResolution;

public class InMemoryEventResolutionRepository implements EventResolutionRepository {

    private final Map<EventIdempotencyScope, ProcessedEventResolution> processed =
            new HashMap<>();

    @Override
    public synchronized Optional<ProcessedEventResolution> findProcessed(
            EventIdempotencyScope scope
    ) {
        return Optional.ofNullable(processed.get(scope));
    }

    @Override
    public synchronized void saveProcessed(
            EventIdempotencyScope scope,
            ProcessedEventResolution value
    ) {
        processed.put(scope, value);
    }
}
