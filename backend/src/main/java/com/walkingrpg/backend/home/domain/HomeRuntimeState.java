package com.walkingrpg.backend.home.domain;

import java.time.Instant;

public record HomeRuntimeState(
        long dailySteps,
        long activityStateVersion,
        String timeZone,
        Instant lastActivitySyncAt,
        long availableEnergy,
        long economyVersion,
        long expeditionProgress,
        long expeditionRequiredEnergy,
        String expeditionStatus,
        long expeditionVersion,
        String currentNodeId,
        String unlockedEventId,
        boolean pilotProgressPresent,
        int pilotLevel,
        int pilotCurrentExperience,
        int pilotNextLevelExperience,
        boolean petProgressPresent,
        int petLevel,
        int petBond,
        String resolvedChoiceId,
        String resolvedChoiceTitle,
        String outcomeTitle,
        String outcomeSummary
) {
    public HomeRuntimeState {
        if (dailySteps < 0 || activityStateVersion < 0) {
            throw new IllegalArgumentException("Activity state не может быть отрицательным");
        }
        if (availableEnergy < 0 || economyVersion < 0) {
            throw new IllegalArgumentException("Economy state не может быть отрицательным");
        }
        if (expeditionProgress < 0 || expeditionRequiredEnergy < 0
                || expeditionVersion < 0) {
            throw new IllegalArgumentException("Expedition state не может быть отрицательным");
        }
        if (pilotLevel < 0 || pilotCurrentExperience < 0
                || pilotNextLevelExperience < 0) {
            throw new IllegalArgumentException("Pilot state не может быть отрицательным");
        }
        if (petLevel < 0 || petBond < 0) {
            throw new IllegalArgumentException("Pet state не может быть отрицательным");
        }
    }

    public HomeRuntimeState(
            long dailySteps,
            long activityStateVersion,
            String timeZone,
            Instant lastActivitySyncAt,
            long availableEnergy,
            long economyVersion,
            long expeditionProgress,
            long expeditionRequiredEnergy,
            String expeditionStatus,
            long expeditionVersion,
            String currentNodeId,
            String unlockedEventId
    ) {
        this(
                dailySteps,
                activityStateVersion,
                timeZone,
                lastActivitySyncAt,
                availableEnergy,
                economyVersion,
                expeditionProgress,
                expeditionRequiredEnergy,
                expeditionStatus,
                expeditionVersion,
                currentNodeId,
                unlockedEventId,
                false,
                0,
                0,
                0,
                false,
                0,
                0,
                null,
                null,
                null,
                null
        );
    }
}
