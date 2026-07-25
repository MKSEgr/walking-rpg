package com.walkingrpg.backend.expedition.application;

import com.walkingrpg.backend.expedition.api.ExpeditionAdvanceRequest;
import com.walkingrpg.backend.expedition.domain.ExpeditionAdvanceCommand;
import org.springframework.stereotype.Component;

@Component
public class ExpeditionAdvanceCommandFactory {

    public ExpeditionAdvanceCommand create(
            String userId,
            String expeditionId,
            ExpeditionAdvanceRequest request
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

        return new ExpeditionAdvanceCommand(
                normalizedUserId,
                normalizedExpeditionId,
                request.energyToSpend(),
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
