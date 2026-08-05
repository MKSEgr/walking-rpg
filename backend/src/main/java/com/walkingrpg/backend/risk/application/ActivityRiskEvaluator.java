package com.walkingrpg.backend.risk.application;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

import com.walkingrpg.backend.activity.domain.ActivityBucket;
import com.walkingrpg.backend.activity.domain.ActivityDayState;
import com.walkingrpg.backend.activity.domain.ActivityRiskStatus;
import com.walkingrpg.backend.activity.domain.ActivitySyncCommand;
import com.walkingrpg.backend.activity.domain.ActivitySyncResult;
import com.walkingrpg.backend.risk.domain.ActivityRiskAssessment;
import com.walkingrpg.backend.risk.domain.ActivityRiskDecision;
import org.springframework.stereotype.Component;

@Component
public class ActivityRiskEvaluator {

    private static final long EXTREME_DAILY_TOTAL = 100_000;
    private static final long EXTREME_DELTA = 50_000;
    private static final double MAX_PLAUSIBLE_STEPS_PER_MINUTE = 250.0;

    public ActivityRiskAssessment evaluate(
            ActivitySyncCommand command,
            ActivityDayState previousState,
            ActivitySyncResult result,
            Instant createdAt
    ) {
        List<String> signals = new ArrayList<>();
        int score = 0;

        if (command.attestation() == null || command.attestation().isBlank()) {
            signals.add("ATTESTATION_MISSING");
            score += 10;
        }
        if (command.authoritativeTotal() >= EXTREME_DAILY_TOTAL) {
            signals.add("DAILY_TOTAL_EXTREME");
            score += 45;
        }
        if (result.acceptedDelta() >= EXTREME_DELTA) {
            signals.add("DELTA_EXTREME");
            score += 35;
        }
        if (result.riskStatus() == ActivityRiskStatus.TOTAL_DECREASED
                || command.authoritativeTotal() < previousState.acceptedTotal()) {
            signals.add("TOTAL_DECREASED");
            score += 20;
        }
        if (bucketTotalMismatches(command)) {
            signals.add("BUCKET_TOTAL_MISMATCH");
            score += 20;
        }
        if (command.buckets().stream().anyMatch(this::impossibleRate)) {
            signals.add("IMPOSSIBLE_STEP_RATE");
            score += 50;
        }
        if (hasSuddenMultiplierGrowth(
                previousState.acceptedTotal(),
                command.authoritativeTotal(),
                result.acceptedDelta()
        )) {
            signals.add("SUDDEN_MULTIPLIER_GROWTH");
            score += 20;
        }

        int normalizedScore = Math.min(score, 100);
        ActivityRiskDecision decision = normalizedScore >= 80
                ? ActivityRiskDecision.BLOCK
                : normalizedScore >= 30
                ? ActivityRiskDecision.REVIEW
                : ActivityRiskDecision.ACCEPT;
        return new ActivityRiskAssessment(
                command.userId(),
                command.deviceId(),
                command.localDate(),
                command.authoritativeTotal(),
                result.acceptedDelta(),
                normalizedScore,
                decision,
                signals,
                createdAt
        );
    }

    private boolean bucketTotalMismatches(ActivitySyncCommand command) {
        if (command.buckets().isEmpty()) {
            return false;
        }
        long bucketTotal = 0;
        try {
            for (ActivityBucket bucket : command.buckets()) {
                bucketTotal = Math.addExact(bucketTotal, bucket.steps());
            }
            long difference = Math.subtractExact(
                    bucketTotal,
                    command.authoritativeTotal()
            );
            return difference > 1_000 || difference < -1_000;
        } catch (ArithmeticException exception) {
            return true;
        }
    }

    private boolean hasSuddenMultiplierGrowth(
            long previousTotal,
            long authoritativeTotal,
            long acceptedDelta
    ) {
        if (previousTotal <= 0 || acceptedDelta <= 10_000) {
            return false;
        }
        try {
            return authoritativeTotal > Math.multiplyExact(previousTotal, 8L);
        } catch (ArithmeticException exception) {
            return false;
        }
    }

    private boolean impossibleRate(ActivityBucket bucket) {
        if (bucket.from() == null || bucket.to() == null || bucket.steps() <= 0) {
            return false;
        }
        long seconds = Duration.between(bucket.from(), bucket.to()).toSeconds();
        if (seconds <= 0) {
            return true;
        }
        double stepsPerMinute = bucket.steps() * 60.0 / seconds;
        return stepsPerMinute > MAX_PLAUSIBLE_STEPS_PER_MINUTE;
    }
}
