package com.walkingrpg.backend.expedition.domain;

public record EventPilotRewardResult(
        String pilotId,
        String name,
        int level,
        int experienceGained,
        int currentExperience,
        int nextLevelExperience,
        long version
) {
}
