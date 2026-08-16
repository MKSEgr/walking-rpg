package com.walkingrpg.backend.expedition.domain;

import java.util.Objects;

public record ExpeditionChoiceSkillRequirement(
        String skillId,
        String skillName,
        String lockedReason
) {
    public ExpeditionChoiceSkillRequirement {
        skillId = requireText(skillId, "skillId");
        skillName = requireText(skillName, "skillName");
        lockedReason = requireText(lockedReason, "lockedReason");
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
