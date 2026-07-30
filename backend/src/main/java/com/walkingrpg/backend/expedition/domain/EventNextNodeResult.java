package com.walkingrpg.backend.expedition.domain;

public record EventNextNodeResult(
        String nodeId,
        String name
) {
    public EventNextNodeResult {
        if (nodeId == null || nodeId.isBlank()) {
            throw new IllegalArgumentException("nodeId обязателен");
        }
        if (name == null || name.isBlank()) {
            throw new IllegalArgumentException("name обязателен");
        }
    }
}
