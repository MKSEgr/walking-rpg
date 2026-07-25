package com.walkingrpg.backend.activity.application;

import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;

import com.walkingrpg.backend.activity.domain.ActivityDayKey;
import com.walkingrpg.backend.activity.domain.ActivityDayState;
import com.walkingrpg.backend.activity.domain.ActivitySyncCalculator;
import com.walkingrpg.backend.activity.domain.ActivitySyncCommand;
import com.walkingrpg.backend.activity.domain.ActivitySyncFingerprint;
import com.walkingrpg.backend.activity.domain.ActivitySyncResult;
import com.walkingrpg.backend.activity.domain.IdempotencyScope;
import com.walkingrpg.backend.activity.domain.ProcessedActivitySync;
import com.walkingrpg.backend.activity.infrastructure.ActivitySyncRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ActivitySyncService {

    private final ActivitySyncRepository repository;
    private final ActivitySyncCalculator calculator;
    private final Clock clock;

    public ActivitySyncService(
            ActivitySyncRepository repository,
            ActivitySyncCalculator calculator,
            Clock clock
    ) {
        this.repository = repository;
        this.calculator = calculator;
        this.clock = clock;
    }

    @Transactional
    public ActivitySyncResult synchronize(ActivitySyncCommand command) {
        Instant serverTime = Instant.now(clock).truncatedTo(ChronoUnit.MICROS);
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
            return processed.result();
        }

        ActivityDayKey dayKey = ActivityDayKey.from(command);
        ActivityDayState currentState = repository.findState(dayKey)
                .orElse(ActivityDayState.initial());
        ActivitySyncResult result = calculator.calculate(currentState, command, serverTime);

        if (result.acceptedTotal() > currentState.acceptedTotal()) {
            repository.saveState(
                    dayKey,
                    new ActivityDayState(result.acceptedTotal(), result.stateVersion()),
                    command.timeZone()
            );
        }
        repository.saveProcessed(
                idempotencyScope,
                new ProcessedActivitySync(requestFingerprint, result)
        );

        return result;
    }
}
