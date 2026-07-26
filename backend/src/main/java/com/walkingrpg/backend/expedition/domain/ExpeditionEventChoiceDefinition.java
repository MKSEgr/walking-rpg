package com.walkingrpg.backend.expedition.domain;

import java.util.Objects;

import com.walkingrpg.backend.inventory.domain.InventoryRewardDefinition;

public record ExpeditionEventChoiceDefinition(
        String choiceId,
        String title,
        String description,
        String outcomeTitle,
        String outcomeSummary,
        int pilotExperienceReward,
        int petBondReward,
        InventoryRewardDefinition materialReward
) {
    public ExpeditionEventChoiceDefinition {
        choiceId = requireText(choiceId, "choiceId");
        title = requireText(title, "title");
        description = requireText(description, "description");
        outcomeTitle = requireText(outcomeTitle, "outcomeTitle");
        outcomeSummary = requireText(outcomeSummary, "outcomeSummary");
        if (pilotExperienceReward < 0 || petBondReward < 0) {
            throw new IllegalArgumentException("Награда progression не может быть отрицательной");
        }
        if (pilotExperienceReward == 0 && petBondReward == 0 && materialReward == null) {
            throw new IllegalArgumentException("Выбор должен содержать положительную награду");
        }
    }

    public ExpeditionEventChoiceDefinition(
            String choiceId,
            String title,
            String description,
            String outcomeTitle,
            String outcomeSummary,
            int pilotExperienceReward,
            int petBondReward
    ) {
        this(
                choiceId,
                title,
                description,
                outcomeTitle,
                outcomeSummary,
                pilotExperienceReward,
                petBondReward,
                null
        );
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
