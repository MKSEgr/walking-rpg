package com.walkingrpg.backend.expedition.application;

import com.walkingrpg.backend.expedition.api.EventResolutionRequest;
import com.walkingrpg.backend.expedition.domain.EventResolutionCommand;
import org.springframework.stereotype.Component;

@Component
public class EventResolutionCommandFactory {

    public EventResolutionCommand create(
            String userId,
            String eventId,
            EventResolutionRequest request
    ) {
        return new EventResolutionCommand(
                requireText(userId, "userId", 128),
                requireText(eventId, "eventId", 64),
                requireText(request.choiceId(), "choiceId", 64),
                requireText(request.idempotencyKey(), "idempotencyKey", 128)
        );
    }

    private String requireText(String value, String field, int maxLength) {
        if (value == null || value.isBlank()) {
            throw new EventResolutionValidationException(
                    field + " обязателен",
                    field
            );
        }
        String normalized = value.trim();
        if (normalized.length() > maxLength) {
            throw new EventResolutionValidationException(
                    field + " превышает " + maxLength + " символов",
                    field
            );
        }
        return normalized;
    }
}
