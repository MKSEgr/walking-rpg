package com.walkingrpg.backend.expedition.infrastructure;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

import com.walkingrpg.backend.expedition.domain.EventIdempotencyScope;
import com.walkingrpg.backend.expedition.domain.EventResultAcknowledgementResult;
import com.walkingrpg.backend.expedition.domain.ProcessedEventResolution;

public interface EventResolutionRepository {

    Optional<ProcessedEventResolution> findProcessed(EventIdempotencyScope scope);

    Optional<ProcessedEventResolution> findPendingResult(
            String userId,
            String expeditionId
    );

    void saveProcessed(
            EventIdempotencyScope scope,
            ProcessedEventResolution processed
    );

    Optional<EventResultAcknowledgementResult> acknowledgeResult(
            String userId,
            UUID receiptId,
            Instant serverTime
    );
}
