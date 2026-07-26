package com.walkingrpg.backend.expedition.domain;

import java.util.Objects;

public record ExpeditionDefinition(
        String contentVersion,
        String expeditionId,
        String name,
        String currentNodeId,
        String currentNodeName,
        long requiredEnergy,
        ExpeditionEventDefinition event
) {
    public ExpeditionDefinition {
        contentVersion = requireText(contentVersion, "contentVersion");
        expeditionId = requireText(expeditionId, "expeditionId");
        name = requireText(name, "name");
        currentNodeId = requireText(currentNodeId, "currentNodeId");
        currentNodeName = requireText(currentNodeName, "currentNodeName");
        if (requiredEnergy <= 0) {
            throw new IllegalArgumentException("requiredEnergy должна быть положительной");
        }
        Objects.requireNonNull(event, "event");
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
