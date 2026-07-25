package com.walkingrpg.backend.home.domain;

public record ExpeditionSnapshot(
        String name,
        String currentNode,
        int progress,
        int requiredEnergy
) {
}
