package com.walkingrpg.backend.platform.application;

import java.util.Set;

public interface PlatformSkillAccess {

    Set<String> unlockedSkills(String userId);

    default boolean isUnlocked(String userId, String skillId) {
        return unlockedSkills(userId).contains(skillId);
    }

    static PlatformSkillAccess none() {
        return userId -> Set.of();
    }
}
