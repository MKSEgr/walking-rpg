package com.walkingrpg.backend.expedition.domain;

import java.util.Objects;

public record ExpeditionEventChoiceDefinition(
        String choiceId,
        String title,
        String description,
        String outcomeTitle,
        String outcomeSummary,
        int pilotExperienceReward,
        int petBondReward
) {
    public ExpeditionEventChoiceDefinition {
        choiceId = requireText(choiceId, "choiceId");
        title = requireText(title, "title");
        description = requireText(description, "description");
        outcomeTitle = requireText(outcomeTitle, "outcomeTitle");
        outcomeSummary = requireText(outcomeSummary, "outcomeSummary");
        if (pilotExperienceReward < 0 || petBondReward < 0
                || (pilotExperienceReward == 0 && petBondReward == 0)) {
            throw new IllegalArgumentException("Выбор должен содержать положительную награду");
        }
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
