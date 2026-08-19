package com.walkingrpg.backend.home.domain;

public record PilotSnapshot(
        String pilotId,
        String name,
        int level,
        int currentExperience,
        int nextLevelExperience,
        String specialization
) {
}
