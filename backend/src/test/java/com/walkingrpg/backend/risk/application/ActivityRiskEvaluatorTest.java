package com.walkingrpg.backend.risk.application;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;

import com.walkingrpg.backend.activity.domain.ActivityBucket;
import com.walkingrpg.backend.activity.domain.ActivityDayState;
import com.walkingrpg.backend.activity.domain.ActivityRiskStatus;
import com.walkingrpg.backend.activity.domain.ActivitySyncCommand;
import com.walkingrpg.backend.activity.domain.ActivitySyncResult;
import com.walkingrpg.backend.risk.domain.ActivityRiskAssessment;
import com.walkingrpg.backend.risk.domain.ActivityRiskDecision;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class ActivityRiskEvaluatorTest {

    private static final Instant NOW = Instant.parse("2026-07-27T08:30:00Z");
    private final ActivityRiskEvaluator evaluator = new ActivityRiskEvaluator();

    @Test
    void shouldAcceptPlausibleAttestedActivity() {
        ActivitySyncCommand command = command(
                3_000,
                List.of(new ActivityBucket(NOW.minusSeconds(3_600), NOW, 3_000)),
                "signed-attestation"
        );
        ActivitySyncResult result = result(3_000, 3_000, ActivityRiskStatus.ACCEPTED);

        ActivityRiskAssessment assessment = evaluator.evaluate(
                command,
                ActivityDayState.initial(),
                result,
                NOW
        );

        assertEquals(0, assessment.riskScore());
        assertEquals(ActivityRiskDecision.ACCEPT, assessment.decision());
        assertTrue(assessment.signals().isEmpty());
    }

    @Test
    void shouldRecordMissingAttestationWithoutBlockingUser() {
        ActivityRiskAssessment assessment = evaluator.evaluate(
                command(2_000, List.of(), null),
                ActivityDayState.initial(),
                result(2_000, 2_000, ActivityRiskStatus.ACCEPTED),
                NOW
        );

        assertEquals(10, assessment.riskScore());
        assertEquals(ActivityRiskDecision.ACCEPT, assessment.decision());
        assertEquals(List.of("ATTESTATION_MISSING"), assessment.signals());
    }

    @Test
    void shouldCapExtremeImpossibleActivityAtBlockScore() {
        ActivitySyncCommand command = command(
                120_000,
                List.of(new ActivityBucket(NOW.minusSeconds(60), NOW, 120_000)),
                "signed-attestation"
        );

        ActivityRiskAssessment assessment = evaluator.evaluate(
                command,
                new ActivityDayState(1_000, 1),
                result(120_000, 119_000, ActivityRiskStatus.ACCEPTED),
                NOW
        );

        assertEquals(100, assessment.riskScore());
        assertEquals(ActivityRiskDecision.BLOCK, assessment.decision());
        assertTrue(assessment.signals().contains("DAILY_TOTAL_EXTREME"));
        assertTrue(assessment.signals().contains("DELTA_EXTREME"));
        assertTrue(assessment.signals().contains("IMPOSSIBLE_STEP_RATE"));
        assertTrue(assessment.signals().contains("SUDDEN_MULTIPLIER_GROWTH"));
    }

    @Test
    void shouldDetectAuthoritativeTotalDecrease() {
        ActivityRiskAssessment assessment = evaluator.evaluate(
                command(4_000, List.of(), "signed-attestation"),
                new ActivityDayState(5_000, 2),
                result(5_000, 0, ActivityRiskStatus.TOTAL_DECREASED),
                NOW
        );

        assertEquals(20, assessment.riskScore());
        assertEquals(ActivityRiskDecision.ACCEPT, assessment.decision());
        assertTrue(assessment.signals().contains("TOTAL_DECREASED"));
    }

    private ActivitySyncCommand command(
            long authoritativeTotal,
            List<ActivityBucket> buckets,
            String attestation
    ) {
        return new ActivitySyncCommand(
                "risk-user",
                "risk-device",
                LocalDate.of(2026, 7, 27),
                ZoneId.of("Europe/Berlin"),
                authoritativeTotal,
                buckets,
                null,
                "risk-key-" + authoritativeTotal,
                attestation
        );
    }

    private ActivitySyncResult result(
            long acceptedTotal,
            long acceptedDelta,
            ActivityRiskStatus riskStatus
    ) {
        return new ActivitySyncResult(
                acceptedTotal,
                acceptedDelta,
                acceptedDelta / 100,
                riskStatus,
                1,
                NOW
        );
    }
}
