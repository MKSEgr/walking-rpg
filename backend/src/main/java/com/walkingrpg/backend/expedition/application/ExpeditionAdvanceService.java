package com.walkingrpg.backend.expedition.application;

import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;

import com.walkingrpg.backend.economy.application.EconomyService;
import com.walkingrpg.backend.economy.domain.WalletSnapshot;
import com.walkingrpg.backend.expedition.domain.ExpeditionAdvanceCommand;
import com.walkingrpg.backend.expedition.domain.ExpeditionAdvanceFingerprint;
import com.walkingrpg.backend.expedition.domain.ExpeditionAdvanceResult;
import com.walkingrpg.backend.expedition.domain.ExpeditionDefinition;
import com.walkingrpg.backend.expedition.domain.ExpeditionIdempotencyScope;
import com.walkingrpg.backend.expedition.domain.ExpeditionProgressState;
import com.walkingrpg.backend.expedition.domain.ExpeditionProgressStatus;
import com.walkingrpg.backend.expedition.domain.ProcessedExpeditionAdvance;
import com.walkingrpg.backend.expedition.domain.ProcessedEventResolution;
import com.walkingrpg.backend.expedition.infrastructure.EventResolutionRepository;
import com.walkingrpg.backend.expedition.infrastructure.ExpeditionRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ExpeditionAdvanceService {

    private final ExpeditionRepository repository;
    private final EventResolutionRepository eventResolutionRepository;
    private final EconomyService economyService;
    private final StarterExpeditionContent content;
    private final ExpeditionContentActivation contentActivation;
    private final Clock clock;

    @Autowired
    public ExpeditionAdvanceService(
            ExpeditionRepository repository,
            EventResolutionRepository eventResolutionRepository,
            EconomyService economyService,
            StarterExpeditionContent content,
            ExpeditionContentActivation contentActivation,
            Clock clock
    ) {
        this.repository = repository;
        this.eventResolutionRepository = eventResolutionRepository;
        this.economyService = economyService;
        this.content = content;
        this.contentActivation = contentActivation;
        this.clock = clock;
    }

    public ExpeditionAdvanceService(
            ExpeditionRepository repository,
            EventResolutionRepository eventResolutionRepository,
            EconomyService economyService,
            StarterExpeditionContent content,
            Clock clock
    ) {
        this(
                repository,
                eventResolutionRepository,
                economyService,
                content,
                () -> StarterExpeditionContent.UNCHARTED_VERGE_CONTENT_VERSION,
                clock
        );
    }

    @Transactional
    public ExpeditionAdvanceResult advance(ExpeditionAdvanceCommand command) {
        content.require(command.expeditionId());
        repository.acquireLock(command.userId(), command.expeditionId());
        Instant serverTime = Instant.now(clock).truncatedTo(ChronoUnit.MICROS);

        ExpeditionIdempotencyScope scope = ExpeditionIdempotencyScope.from(command);
        String fingerprint = ExpeditionAdvanceFingerprint.sha256(command);
        ProcessedExpeditionAdvance processed = repository.findProcessed(scope)
                .orElse(null);
        if (processed != null) {
            if (!processed.requestFingerprint().equals(fingerprint)) {
                throw new ExpeditionIdempotencyConflictException();
            }
            return processed.result();
        }
        requireNoPendingResult(command.userId(), command.expeditionId());
        String activeContentVersion = content.activeContentVersion(
                contentActivation
        );

        ExpeditionProgressState current = repository.findState(
                command.userId(),
                command.expeditionId()
        ).orElseGet(() -> ExpeditionProgressState.initial(content.initialDefinition()));
        ExpeditionDefinition node = content.requireNode(current.currentNodeId());

        validateStateAndAmount(current, command.energyToSpend());

        WalletSnapshot wallet = economyService.debitExpeditionEnergy(
                command.userId(),
                command.energyToSpend(),
                economySourceKey(scope),
                serverTime
        );
        ExpeditionProgressState updated = current.advance(
                command.energyToSpend(),
                node
        );
        ExpeditionAdvanceResult result = new ExpeditionAdvanceResult(
                activeContentVersion,
                node.expeditionId(),
                node.name(),
                command.energyToSpend(),
                wallet.balance(),
                wallet.version(),
                updated.progressEnergy(),
                updated.requiredEnergy(),
                updated.version(),
                updated.status(),
                updated.currentNodeId(),
                node.currentNodeName(),
                updated.status() == ExpeditionProgressStatus.EVENT_READY
                        ? node.event()
                        : null,
                serverTime
        );

        repository.saveState(command.userId(), command.expeditionId(), updated, serverTime);
        repository.saveProcessed(
                scope,
                new ProcessedExpeditionAdvance(fingerprint, result)
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

    private void validateStateAndAmount(
            ExpeditionProgressState state,
            long energyToSpend
    ) {
        if (energyToSpend <= 0) {
            throw new ExpeditionValidationException(
                    "energyToSpend должна быть положительной",
                    "energyToSpend"
            );
        }
        if (state.status() != ExpeditionProgressStatus.IN_PROGRESS) {
            throw new ExpeditionStateConflictException(
                    "Продвижение недоступно в статусе " + state.status(),
                    state.status(),
                    0
            );
        }
        if (energyToSpend > state.remainingEnergy()) {
            throw new ExpeditionStateConflictException(
                    "energyToSpend превышает остаток до текущего узла",
                    state.status(),
                    state.remainingEnergy()
            );
        }
    }

    private String economySourceKey(ExpeditionIdempotencyScope scope) {
        return scope.expeditionId().length()
                + ":"
                + scope.expeditionId()
                + ":"
                + scope.idempotencyKey();
    }
}
