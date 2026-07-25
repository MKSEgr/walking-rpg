package com.walkingrpg.backend.activity.application;

import java.time.Clock;
import java.time.Instant;

import com.walkingrpg.backend.activity.domain.ActivityDayKey;
import com.walkingrpg.backend.activity.domain.ActivityDayState;
import com.walkingrpg.backend.activity.domain.ActivitySyncCalculator;
import com.walkingrpg.backend.activity.domain.ActivitySyncCommand;
import com.walkingrpg.backend.activity.domain.ActivitySyncResult;
import com.walkingrpg.backend.activity.domain.IdempotencyScope;
import com.walkingrpg.backend.activity.domain.ProcessedActivitySync;
import com.walkingrpg.backend.activity.infrastructure.ActivitySyncRepository;
import org.springframework.stereotype.Service;

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

    public synchronized ActivitySyncResult synchronize(ActivitySyncCommand command) {
        IdempotencyScope idempotencyScope = IdempotencyScope.from(command);
        ProcessedActivitySync processed = repository.findProcessed(idempotencyScope)
                .orElse(null);

        if (processed != null) {
            if (!processed.command().equals(command)) {
                throw new ActivitySyncConflictException(
                        "idempotencyKey уже использован для другого запроса"
                );
            }
            return processed.result();
        }

        ActivityDayKey dayKey = ActivityDayKey.from(command);
        ActivityDayState currentState = repository.findState(dayKey)
                .orElse(ActivityDayState.initial());
        Instant serverTime = Instant.now(clock);
        ActivitySyncResult result = calculator.calculate(currentState, command, serverTime);

        if (result.acceptedTotal() > currentState.acceptedTotal()) {
            repository.saveState(
                    dayKey,
                    new ActivityDayState(result.acceptedTotal(), result.stateVersion())
            );
        }
        repository.saveProcessed(
                idempotencyScope,
                new ProcessedActivitySync(command, result)
        );

        return result;
    }
}
