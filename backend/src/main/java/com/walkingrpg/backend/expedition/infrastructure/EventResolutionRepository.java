package com.walkingrpg.backend.expedition.infrastructure;

import java.util.Optional;

import com.walkingrpg.backend.expedition.domain.EventIdempotencyScope;
import com.walkingrpg.backend.expedition.domain.ProcessedEventResolution;

public interface EventResolutionRepository {

    Optional<ProcessedEventResolution> findProcessed(EventIdempotencyScope scope);

    void saveProcessed(
            EventIdempotencyScope scope,
            ProcessedEventResolution processed
    );
}
