package com.walkingrpg.backend.platform.domain;

import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.time.temporal.TemporalAdjusters;
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
        long version,
        LocalDate weeklyRouteWeekStart,
        Boolean weeklyRouteRewardClaimed
) {
    public static final int CURRENT_SCHEMA_VERSION = 2;

    public PlatformUserState {
        // Nullable at the JSON boundary so strict mappers can read schema v1,
        // whose record did not have this receipt field.
        weeklyRouteRewardClaimed = Boolean.TRUE.equals(weeklyRouteRewardClaimed);
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
        if (weeklyRouteWeekStart != null
                && weeklyRouteWeekStart.getDayOfWeek() != DayOfWeek.MONDAY) {
            throw new IllegalArgumentException("Недельный маршрут начинается в понедельник UTC");
        }
    }

    public static LocalDate weeklyRouteWeekStart(Instant observedAt) {
        return observedAt.atOffset(ZoneOffset.UTC).toLocalDate()
                .with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY));
    }

    /**
     * Old JSON has neither a period nor a reward receipt. Its persisted update
     * time anchors that progress; the old completion achievement is the receipt.
     * This projection never awards XP and is persisted by the next real command.
     */
    public PlatformUserState initializeWeeklyRoutePeriod(Instant updatedAt) {
        if (weeklyRouteWeekStart != null) {
            return this;
        }
        return withWeeklyRoutePeriod(
                weeklyRouteWeekStart(updatedAt),
                achievements.contains("weekly-route-complete"),
                weeklyRouteProgress,
                seasonXp
        );
    }

    public PlatformUserState withWeeklyRoutePeriod(
            LocalDate weekStart,
            boolean rewardClaimed,
            int progress,
            int xp
    ) {
        return new PlatformUserState(
                Math.max(schemaVersion, CURRENT_SCHEMA_VERSION), activePetId, pets,
                completedOnboardingSteps, unlockedSkills, claimedQuests, achievements,
                xp, progress, squadId, ownedCosmetics, activeCosmeticId,
                experimentAssignments, version, weekStart, rewardClaimed
        );
    }
}
