package com.walkingrpg.backend.expedition.domain;

import java.util.Objects;

public record ExpeditionEventDefinition(
        String eventId,
        String title,
        String summary
) {
    public ExpeditionEventDefinition {
        eventId = requireText(eventId, "eventId");
        title = requireText(title, "title");
        summary = requireText(summary, "summary");
    }

    private static String requireText(String value, String field) {
        Objects.requireNonNull(value, field);
        String normalized = value.trim();
        if (normalized.isEmpty()) {
            throw new IllegalArgumentException(field + " обязателен");
        }
        return normalized;
    }
}
