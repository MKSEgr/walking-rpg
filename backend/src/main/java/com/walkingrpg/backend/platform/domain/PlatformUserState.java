package com.walkingrpg.backend.platform.domain;

import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.Map;
import java.util.Set;

public record PlatformUserState(
        int schemaVersion,
        String activePetId,
        Map<String, PlatformPetProgress> pets,
        Set<String> completedOnboardingSteps,
        Set<String> unlockedSkills,
        Set<String> claimedQuests,
        Set<String> achievements,
        int seasonXp,
        int weeklyRouteProgress,
        String squadId,
        Set<String> ownedCosmetics,
        String activeCosmeticId,
        Map<String, String> experimentAssignments,
        long version
) {
    public static final int CURRENT_SCHEMA_VERSION = 1;

    public PlatformUserState {
        if (schemaVersion <= 0) {
            throw new IllegalArgumentException("schemaVersion должна быть положительной");
        }
        if (activePetId == null || activePetId.isBlank()) {
            throw new IllegalArgumentException("activePetId обязателен");
        }
        pets = Map.copyOf(new LinkedHashMap<>(pets == null ? Map.of() : pets));
        if (!pets.containsKey(activePetId)) {
            throw new IllegalArgumentException("Активный питомец отсутствует в pets");
        }
        completedOnboardingSteps = Set.copyOf(new LinkedHashSet<>(
                completedOnboardingSteps == null ? Set.of() : completedOnboardingSteps
        ));
        unlockedSkills = Set.copyOf(new LinkedHashSet<>(
                unlockedSkills == null ? Set.of() : unlockedSkills
        ));
        claimedQuests = Set.copyOf(new LinkedHashSet<>(
                claimedQuests == null ? Set.of() : claimedQuests
        ));
        achievements = Set.copyOf(new LinkedHashSet<>(
                achievements == null ? Set.of() : achievements
        ));
        ownedCosmetics = Set.copyOf(new LinkedHashSet<>(
                ownedCosmetics == null ? Set.of() : ownedCosmetics
        ));
        experimentAssignments = Map.copyOf(new LinkedHashMap<>(
                experimentAssignments == null ? Map.of() : experimentAssignments
        ));
        if (seasonXp < 0 || weeklyRouteProgress < 0 || version < 0) {
            throw new IllegalArgumentException("Platform progress не может быть отрицательным");
        }
        if (activeCosmeticId != null && !ownedCosmetics.contains(activeCosmeticId)) {
            throw new IllegalArgumentException("Активная косметика не приобретена");
        }
    }
}
