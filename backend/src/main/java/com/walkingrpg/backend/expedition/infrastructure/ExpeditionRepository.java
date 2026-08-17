package com.walkingrpg.backend.expedition.infrastructure;

import java.time.Instant;
import java.util.Optional;

import com.walkingrpg.backend.expedition.domain.ExpeditionIdempotencyScope;
import com.walkingrpg.backend.expedition.domain.ExpeditionProgressState;
import com.walkingrpg.backend.expedition.domain.ProcessedExpeditionAdvance;
import com.walkingrpg.backend.expedition.domain.ProcessedExpeditionJourneyStart;

public interface ExpeditionRepository {

    void acquireLock(String userId, String expeditionId);

    Optional<ExpeditionProgressState> findState(String userId, String expeditionId);

    void saveState(
            String userId,
            String expeditionId,
            ExpeditionProgressState state,
            Instant updatedAt
    );

    Optional<ProcessedExpeditionAdvance> findProcessed(
            ExpeditionIdempotencyScope scope
    );

    void saveProcessed(
            ExpeditionIdempotencyScope scope,
            ProcessedExpeditionAdvance processed
    );

    long findJourneyNumber(String userId, String expeditionId);

    void saveJourneyNumber(
            String userId,
            String expeditionId,
            long journeyNumber,
            Instant updatedAt
    );

    Optional<ProcessedExpeditionJourneyStart> findProcessedJourney(
            ExpeditionIdempotencyScope scope
    );

    void saveProcessedJourney(
            ExpeditionIdempotencyScope scope,
            ProcessedExpeditionJourneyStart processed
    );
}
