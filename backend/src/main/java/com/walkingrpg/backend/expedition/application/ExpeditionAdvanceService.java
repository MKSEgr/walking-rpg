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
import com.walkingrpg.backend.expedition.infrastructure.ExpeditionRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ExpeditionAdvanceService {

    private final ExpeditionRepository repository;
    private final EconomyService economyService;
    private final StarterExpeditionContent content;
    private final Clock clock;

    public ExpeditionAdvanceService(
            ExpeditionRepository repository,
            EconomyService economyService,
            StarterExpeditionContent content,
            Clock clock
    ) {
        this.repository = repository;
        this.economyService = economyService;
        this.content = content;
        this.clock = clock;
    }

    @Transactional
    public ExpeditionAdvanceResult advance(ExpeditionAdvanceCommand command) {
        ExpeditionDefinition definition = content.require(command.expeditionId());
        Instant serverTime = Instant.now(clock).truncatedTo(ChronoUnit.MICROS);
        repository.acquireLock(command.userId(), command.expeditionId());

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

        ExpeditionProgressState current = repository.findState(
                command.userId(),
                command.expeditionId()
        ).orElseGet(() -> ExpeditionProgressState.initial(definition));

        validateStateAndAmount(current, command.energyToSpend());

        WalletSnapshot wallet = economyService.debitExpeditionEnergy(
                command.userId(),
                command.energyToSpend(),
                economySourceKey(scope),
                serverTime
        );
        ExpeditionProgressState updated = current.advance(
                command.energyToSpend(),
                definition
        );
        ExpeditionAdvanceResult result = new ExpeditionAdvanceResult(
                definition.contentVersion(),
                definition.expeditionId(),
                definition.name(),
                command.energyToSpend(),
                wallet.balance(),
                wallet.version(),
                updated.progressEnergy(),
                updated.requiredEnergy(),
                updated.version(),
                updated.status(),
                updated.currentNodeId(),
                definition.currentNodeName(),
                updated.status() == ExpeditionProgressStatus.EVENT_READY
                        ? definition.event()
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
        if (state.status() == ExpeditionProgressStatus.EVENT_READY) {
            throw new ExpeditionStateConflictException(
                    "Первый узел уже достигнут, сначала требуется обработать событие",
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
