package com.walkingrpg.backend.home.domain;

public record PilotSnapshot(
        String name,
        int level,
        int currentExperience,
        int nextLevelExperience,
        String specialization
) {
}
