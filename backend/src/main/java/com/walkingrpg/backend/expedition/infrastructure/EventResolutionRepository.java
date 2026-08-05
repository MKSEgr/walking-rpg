package com.walkingrpg.backend.expedition.infrastructure;

import java.time.Instant;
import java.util.Objects;
import java.util.Optional;
import java.util.UUID;
import java.util.function.Supplier;

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
            Supplier<Instant> serverTimeSupplier
    );

    default Optional<EventResultAcknowledgementResult> acknowledgeResult(
            String userId,
            UUID receiptId,
            Instant serverTime
    ) {
        Objects.requireNonNull(serverTime, "serverTime");
        return acknowledgeResult(userId, receiptId, () -> serverTime);
    }
}
