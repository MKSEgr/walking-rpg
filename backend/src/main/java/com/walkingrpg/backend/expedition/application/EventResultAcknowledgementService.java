package com.walkingrpg.backend.expedition.application;

import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;

import com.walkingrpg.backend.expedition.domain.EventResultAcknowledgementResult;
import com.walkingrpg.backend.expedition.infrastructure.EventResolutionRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class EventResultAcknowledgementService {

    private final EventResolutionRepository repository;
    private final Clock clock;

    public EventResultAcknowledgementService(
            EventResolutionRepository repository,
            Clock clock
    ) {
        this.repository = repository;
        this.clock = clock;
    }

    @Transactional
    public EventResultAcknowledgementResult acknowledge(
            String userId,
            UUID receiptId
    ) {
        requireText(userId, "userId");
        Instant serverTime = Instant.now(clock).truncatedTo(ChronoUnit.MICROS);
        return repository.acknowledgeResult(userId, receiptId, serverTime)
                .orElseThrow(() -> new EventResultReceiptNotFoundException(receiptId));
    }

    private void requireText(String value, String field) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException(field + " обязателен");
        }
    }
}
