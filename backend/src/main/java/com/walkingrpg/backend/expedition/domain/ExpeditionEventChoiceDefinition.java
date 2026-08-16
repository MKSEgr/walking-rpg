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
        InventoryRewardDefinition materialReward,
        ExpeditionChoiceEquipmentRequirement equipmentRequirement,
        ExpeditionChoicePetRequirement petRequirement,
        ExpeditionChoiceSkillRequirement skillRequirement
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
        int requirementCount = (equipmentRequirement == null ? 0 : 1)
                + (petRequirement == null ? 0 : 1)
                + (skillRequirement == null ? 0 : 1);
        if (requirementCount > 1) {
            throw new IllegalArgumentException(
                    "Выбор поддерживает только одно обязательное условие"
            );
        }
    }

    public ExpeditionEventChoiceDefinition(
            String choiceId,
            String title,
            String description,
            String outcomeTitle,
            String outcomeSummary,
            int pilotExperienceReward,
            int petBondReward,
            InventoryRewardDefinition materialReward,
            ExpeditionChoiceEquipmentRequirement equipmentRequirement
    ) {
        this(
                choiceId,
                title,
                description,
                outcomeTitle,
                outcomeSummary,
                pilotExperienceReward,
                petBondReward,
                materialReward,
                equipmentRequirement,
                null,
                null
        );
    }

    public ExpeditionEventChoiceDefinition(
            String choiceId,
            String title,
            String description,
            String outcomeTitle,
            String outcomeSummary,
            int pilotExperienceReward,
            int petBondReward,
            InventoryRewardDefinition materialReward,
            ExpeditionChoicePetRequirement petRequirement
    ) {
        this(
                choiceId,
                title,
                description,
                outcomeTitle,
                outcomeSummary,
                pilotExperienceReward,
                petBondReward,
                materialReward,
                null,
                petRequirement,
                null
        );
    }

    public ExpeditionEventChoiceDefinition(
            String choiceId,
            String title,
            String description,
            String outcomeTitle,
            String outcomeSummary,
            int pilotExperienceReward,
            int petBondReward,
            InventoryRewardDefinition materialReward,
            ExpeditionChoiceSkillRequirement skillRequirement
    ) {
        this(
                choiceId,
                title,
                description,
                outcomeTitle,
                outcomeSummary,
                pilotExperienceReward,
                petBondReward,
                materialReward,
                null,
                null,
                skillRequirement
        );
    }

    public ExpeditionEventChoiceDefinition(
            String choiceId,
            String title,
            String description,
            String outcomeTitle,
            String outcomeSummary,
            int pilotExperienceReward,
            int petBondReward,
            InventoryRewardDefinition materialReward
    ) {
        this(
                choiceId,
                title,
                description,
                outcomeTitle,
                outcomeSummary,
                pilotExperienceReward,
                petBondReward,
                materialReward,
                null,
                null,
                null
        );
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
                null,
                null,
                null,
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
