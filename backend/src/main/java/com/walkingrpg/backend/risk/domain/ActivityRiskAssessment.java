package com.walkingrpg.backend.risk.domain;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

public record ActivityRiskAssessment(
        String userId,
        String deviceId,
        LocalDate localDate,
        long authoritativeTotal,
        long acceptedDelta,
        int riskScore,
        ActivityRiskDecision decision,
        List<String> signals,
        Instant createdAt
) {
    public ActivityRiskAssessment {
        if (riskScore < 0 || riskScore > 100) {
            throw new IllegalArgumentException("riskScore должен быть от 0 до 100");
        }
        signals = signals == null ? List.of() : List.copyOf(signals);
    }
}
