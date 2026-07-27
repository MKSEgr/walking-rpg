package com.walkingrpg.backend.risk.application;

import java.time.Instant;

import com.walkingrpg.backend.activity.domain.ActivityDayState;
import com.walkingrpg.backend.activity.domain.ActivitySyncCommand;
import com.walkingrpg.backend.activity.domain.ActivitySyncResult;
import com.walkingrpg.backend.risk.domain.ActivityRiskAssessment;

public interface ActivityRiskRecorder {

    ActivityRiskAssessment record(
            ActivitySyncCommand command,
            ActivityDayState previousState,
            ActivitySyncResult result,
            Instant createdAt
    );

    static ActivityRiskRecorder noop() {
        ActivityRiskEvaluator evaluator = new ActivityRiskEvaluator();
        return evaluator::evaluate;
    }
}
