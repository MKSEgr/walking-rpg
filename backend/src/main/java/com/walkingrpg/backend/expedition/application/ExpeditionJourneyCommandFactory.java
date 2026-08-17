package com.walkingrpg.backend.expedition.application;

import com.walkingrpg.backend.expedition.api.ExpeditionJourneyRequest;
import com.walkingrpg.backend.expedition.domain.ExpeditionJourneyCommand;
import org.springframework.stereotype.Component;

@Component
public class ExpeditionJourneyCommandFactory {

    public ExpeditionJourneyCommand create(
            String userId,
            String expeditionId,
            ExpeditionJourneyRequest request
    ) {
        String normalizedUserId = requireText(userId, "userId", 128);
        String normalizedExpeditionId = requireText(
                expeditionId,
                "expeditionId",
                64
        );
        String normalizedKey = requireText(
                request.idempotencyKey(),
                "idempotencyKey",
                128
        );
        return new ExpeditionJourneyCommand(
                normalizedUserId,
                normalizedExpeditionId,
                request.expectedJourneyNumber(),
                normalizedKey
        );
    }

    private String requireText(String value, String field, int maxLength) {
        if (value == null || value.isBlank()) {
            throw new ExpeditionValidationException(
                    field + " обязателен",
                    field
            );
        }
        String normalized = value.trim();
        if (normalized.length() > maxLength) {
            throw new ExpeditionValidationException(
                    field + " превышает " + maxLength + " символов",
                    field
            );
        }
        return normalized;
    }
}
