package com.walkingrpg.backend.expedition.infrastructure;

import java.time.Instant;
import java.util.Comparator;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import com.walkingrpg.backend.expedition.domain.EventIdempotencyScope;
import com.walkingrpg.backend.expedition.domain.EventResultAcknowledgementResult;
import com.walkingrpg.backend.expedition.domain.ProcessedEventResolution;

public class InMemoryEventResolutionRepository implements EventResolutionRepository {

    private final Map<EventIdempotencyScope, ProcessedEventResolution> processed =
            new HashMap<>();
    private final Map<UUID, Instant> acknowledgedAt = new HashMap<>();

    @Override
    public synchronized Optional<ProcessedEventResolution> findProcessed(
            EventIdempotencyScope scope
    ) {
        return Optional.ofNullable(processed.get(scope));
    }

    @Override
    public synchronized Optional<ProcessedEventResolution> findPendingResult(
            String userId,
            String expeditionId
    ) {
        return processed.entrySet().stream()
                .filter(entry -> entry.getKey().userId().equals(userId))
                .map(Map.Entry::getValue)
                .filter(value -> value.result().expeditionId().equals(expeditionId))
                .filter(value -> !acknowledgedAt.containsKey(value.result().receiptId()))
                .min(Comparator.comparing(value -> value.result().serverTime()));
    }

    @Override
    public synchronized void saveProcessed(
            EventIdempotencyScope scope,
            ProcessedEventResolution value
    ) {
        processed.put(scope, value);
        if (!value.result().handoffRequired()) {
            acknowledgedAt.put(
                    value.result().receiptId(),
                    value.result().serverTime()
            );
        }
    }

    @Override
    public synchronized Optional<EventResultAcknowledgementResult> acknowledgeResult(
            String userId,
            UUID receiptId,
            Instant serverTime
    ) {
        return processed.entrySet().stream()
                .filter(entry -> entry.getKey().userId().equals(userId))
                .map(Map.Entry::getValue)
                .filter(value -> value.result().receiptId().equals(receiptId))
                .findFirst()
                .map(value -> {
                    Instant operationTime = acknowledgedAt.computeIfAbsent(
                            receiptId,
                            ignored -> value.result().serverTime().isAfter(serverTime)
                                    ? value.result().serverTime()
                                    : serverTime
                    );
                    return new EventResultAcknowledgementResult(
                            receiptId,
                            value.result().eventId(),
                            operationTime,
                            operationTime
                    );
                });
    }
}
