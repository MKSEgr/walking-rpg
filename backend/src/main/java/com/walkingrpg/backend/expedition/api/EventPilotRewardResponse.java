package com.walkingrpg.backend.expedition.api;

public record EventPilotRewardResponse(
        String pilotId,
        String name,
        int level,
        int experienceGained,
        int currentExperience,
        int nextLevelExperience,
        long version
) {
}
