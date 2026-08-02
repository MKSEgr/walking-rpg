package com.walkingrpg.backend.activity.application;

import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;

import com.walkingrpg.backend.activity.domain.ActivityDayKey;
import com.walkingrpg.backend.activity.domain.ActivityDayState;
import com.walkingrpg.backend.activity.domain.ActivitySyncCalculator;
import com.walkingrpg.backend.activity.domain.ActivitySyncCommand;
import com.walkingrpg.backend.activity.domain.ActivitySyncFingerprint;
import com.walkingrpg.backend.activity.domain.ActivitySyncOutcome;
import com.walkingrpg.backend.activity.domain.ActivitySyncResult;
import com.walkingrpg.backend.activity.domain.IdempotencyScope;
import com.walkingrpg.backend.activity.domain.ProcessedActivitySync;
import com.walkingrpg.backend.activity.infrastructure.ActivitySyncRepository;
import com.walkingrpg.backend.economy.application.EconomyService;
import com.walkingrpg.backend.economy.domain.WalletSnapshot;
import com.walkingrpg.backend.risk.application.ActivityRiskRecorder;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ActivitySyncService {

    private final ActivitySyncRepository repository;
    private final ActivitySyncCalculator calculator;
    private final EconomyService economyService;
    private final ActivityRiskRecorder riskRecorder;
    private final Clock clock;

    @Autowired
    public ActivitySyncService(
            ActivitySyncRepository repository,
            ActivitySyncCalculator calculator,
            EconomyService economyService,
            ActivityRiskRecorder riskRecorder,
            Clock clock
    ) {
        this.repository = repository;
        this.calculator = calculator;
        this.economyService = economyService;
        this.riskRecorder = riskRecorder;
        this.clock = clock;
    }

    public ActivitySyncService(
            ActivitySyncRepository repository,
            ActivitySyncCalculator calculator,
            EconomyService economyService,
            Clock clock
    ) {
        this(
                repository,
                calculator,
                economyService,
                ActivityRiskRecorder.noop(),
                clock
        );
    }

    @Transactional
    public ActivitySyncOutcome synchronize(ActivitySyncCommand command) {
        Instant serverTime = Instant.now(clock).truncatedTo(ChronoUnit.MICROS);
        validateLocalDate(command, serverTime);
        repository.acquireUserLock(command.userId());
        repository.registerDevice(command.userId(), command.deviceId(), serverTime);

        IdempotencyScope idempotencyScope = IdempotencyScope.from(command);
        String requestFingerprint = ActivitySyncFingerprint.sha256(command);
        ProcessedActivitySync processed = repository.findProcessed(idempotencyScope)
                .orElse(null);

        if (processed != null) {
            if (!processed.requestFingerprint().equals(requestFingerprint)) {
                throw new ActivitySyncConflictException(
                        "idempotencyKey уже использован для другого запроса"
                );
            }
            return processed.outcome();
        }

        ActivityDayKey dayKey = ActivityDayKey.from(command);
        ActivityDayState currentState = repository.findState(dayKey)
                .orElse(ActivityDayState.initial());
        ActivitySyncResult result = calculator.calculate(currentState, command, serverTime);
        riskRecorder.record(command, currentState, result, serverTime);
        WalletSnapshot wallet = economyService.creditActivityEnergy(
                command.userId(),
                result.energyGranted(),
                ledgerSourceKey(idempotencyScope),
                serverTime
        );
        ActivitySyncOutcome outcome = new ActivitySyncOutcome(
                result,
                wallet.balance(),
                wallet.version()
        );

        if (result.acceptedTotal() > currentState.acceptedTotal()) {
            repository.saveState(
                    dayKey,
                    new ActivityDayState(result.acceptedTotal(), result.stateVersion()),
                    command.timeZone()
            );
        }
        repository.saveProcessed(
                idempotencyScope,
                new ProcessedActivitySync(requestFingerprint, outcome)
        );
        repository.markSuccessfulSync(command.userId());

        return outcome;
    }

    private void validateLocalDate(ActivitySyncCommand command, Instant serverTime) {
        if (command.localDate().isAfter(
                serverTime.atZone(command.timeZone()).toLocalDate()
        )) {
            throw new ActivitySyncValidationException(
                    "localDate",
                    "localDate не может быть позже текущей даты в указанном timeZone"
            );
        }
    }

    private String ledgerSourceKey(IdempotencyScope scope) {
        return scope.deviceId().length()
                + ":"
                + scope.deviceId()
                + ":"
                + scope.idempotencyKey();
    }
}
