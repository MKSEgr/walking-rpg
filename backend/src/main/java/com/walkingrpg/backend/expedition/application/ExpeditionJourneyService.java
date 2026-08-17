package com.walkingrpg.backend.expedition.application;

import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;

import com.walkingrpg.backend.expedition.domain.ExpeditionDefinition;
import com.walkingrpg.backend.expedition.domain.ExpeditionIdempotencyScope;
import com.walkingrpg.backend.expedition.domain.ExpeditionJourneyCommand;
import com.walkingrpg.backend.expedition.domain.ExpeditionJourneyFingerprint;
import com.walkingrpg.backend.expedition.domain.ExpeditionJourneyStartResult;
import com.walkingrpg.backend.expedition.domain.ExpeditionProgressState;
import com.walkingrpg.backend.expedition.domain.ExpeditionProgressStatus;
import com.walkingrpg.backend.expedition.domain.ProcessedEventResolution;
import com.walkingrpg.backend.expedition.domain.ProcessedExpeditionJourneyStart;
import com.walkingrpg.backend.expedition.infrastructure.EventResolutionRepository;
import com.walkingrpg.backend.expedition.infrastructure.ExpeditionRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ExpeditionJourneyService {

    private final ExpeditionRepository repository;
    private final EventResolutionRepository eventResolutionRepository;
    private final StarterExpeditionContent content;
    private final ExpeditionContentActivation contentActivation;
    private final Clock clock;

    public ExpeditionJourneyService(
            ExpeditionRepository repository,
            EventResolutionRepository eventResolutionRepository,
            StarterExpeditionContent content,
            ExpeditionContentActivation contentActivation,
            Clock clock
    ) {
        this.repository = repository;
        this.eventResolutionRepository = eventResolutionRepository;
        this.content = content;
        this.contentActivation = contentActivation;
        this.clock = clock;
    }

    @Transactional
    public ExpeditionJourneyStartResult beginNextJourney(
            ExpeditionJourneyCommand command
    ) {
        content.require(command.expeditionId());
        repository.acquireLock(command.userId(), command.expeditionId());
        Instant serverTime = Instant.now(clock).truncatedTo(ChronoUnit.MICROS);

        ExpeditionIdempotencyScope scope = ExpeditionIdempotencyScope.from(
                command
        );
        String fingerprint = ExpeditionJourneyFingerprint.sha256(command);
        ProcessedExpeditionJourneyStart processed = repository
                .findProcessedJourney(scope)
                .orElse(null);
        if (processed != null) {
            if (!processed.requestFingerprint().equals(fingerprint)) {
                throw new ExpeditionIdempotencyConflictException();
            }
            return processed.result();
        }

        requireNoPendingResult(command.userId(), command.expeditionId());
        ExpeditionProgressState current = repository.findState(
                command.userId(),
                command.expeditionId()
        ).orElseGet(() -> ExpeditionProgressState.initial(
                content.initialDefinition()
        ));
        long currentJourneyNumber = repository.findJourneyNumber(
                command.userId(),
                command.expeditionId()
        );
        validateState(
                current,
                command.expectedJourneyNumber(),
                currentJourneyNumber
        );

        ExpeditionDefinition initialDefinition = content.initialDefinition();
        ExpeditionProgressState updated = current.beginNextJourney(
                initialDefinition
        );
        long nextJourneyNumber = Math.addExact(currentJourneyNumber, 1);
        ExpeditionJourneyStartResult result = new ExpeditionJourneyStartResult(
                content.activeContentVersion(contentActivation),
                initialDefinition.expeditionId(),
                initialDefinition.name(),
                nextJourneyNumber,
                updated.progressEnergy(),
                updated.requiredEnergy(),
                updated.version(),
                updated.status(),
                updated.currentNodeId(),
                initialDefinition.currentNodeName(),
                serverTime
        );

        repository.saveState(
                command.userId(),
                command.expeditionId(),
                updated,
                serverTime
        );
        repository.saveJourneyNumber(
                command.userId(),
                command.expeditionId(),
                nextJourneyNumber,
                serverTime
        );
        repository.saveProcessedJourney(
                scope,
                new ProcessedExpeditionJourneyStart(fingerprint, result)
        );
        return result;
    }

    private void requireNoPendingResult(String userId, String expeditionId) {
        eventResolutionRepository.findPendingResult(userId, expeditionId)
                .map(ProcessedEventResolution::result)
                .ifPresent(result -> {
                    throw new PendingEventResultException(
                            result.receiptId(),
                            result.eventId()
                    );
                });
    }

    private void validateState(
            ExpeditionProgressState state,
            long expectedJourneyNumber,
            long currentJourneyNumber
    ) {
        if (expectedJourneyNumber != currentJourneyNumber) {
            throw new ExpeditionJourneyStateConflictException(
                    "Номер похода изменился; обновите состояние",
                    state.status(),
                    expectedJourneyNumber,
                    currentJourneyNumber
            );
        }
        if (state.status() != ExpeditionProgressStatus.COMPLETED) {
            throw new ExpeditionJourneyStateConflictException(
                    "Новый поход доступен только после завершения экспедиции",
                    state.status(),
                    expectedJourneyNumber,
                    currentJourneyNumber
            );
        }
    }
}
