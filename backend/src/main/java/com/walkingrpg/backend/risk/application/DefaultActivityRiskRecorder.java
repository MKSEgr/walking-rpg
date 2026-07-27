package com.walkingrpg.backend.risk.application;

import java.time.Instant;

import com.walkingrpg.backend.activity.domain.ActivityDayState;
import com.walkingrpg.backend.activity.domain.ActivitySyncCommand;
import com.walkingrpg.backend.activity.domain.ActivitySyncResult;
import com.walkingrpg.backend.risk.domain.ActivityRiskAssessment;
import com.walkingrpg.backend.risk.infrastructure.ActivityRiskRepository;
import org.springframework.stereotype.Service;

@Service
public class DefaultActivityRiskRecorder implements ActivityRiskRecorder {

    private final ActivityRiskEvaluator evaluator;
    private final ActivityRiskRepository repository;

    public DefaultActivityRiskRecorder(
            ActivityRiskEvaluator evaluator,
            ActivityRiskRepository repository
    ) {
        this.evaluator = evaluator;
        this.repository = repository;
    }

    @Override
    public ActivityRiskAssessment record(
            ActivitySyncCommand command,
            ActivityDayState previousState,
            ActivitySyncResult result,
            Instant createdAt
    ) {
        ActivityRiskAssessment assessment = evaluator.evaluate(
                command,
                previousState,
                result,
                createdAt
        );
        repository.save(assessment);
        return assessment;
    }
}
