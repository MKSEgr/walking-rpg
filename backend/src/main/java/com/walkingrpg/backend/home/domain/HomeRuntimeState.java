package com.walkingrpg.backend.home.domain;

import java.time.Instant;
import java.util.List;

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
        String outcomeSummary,
        String materialItemId,
        String materialItemName,
        String materialItemDescription,
        Long materialQuantityGained,
        Long materialQuantityAfter,
        Long materialVersion,
        List<InventoryRuntimeItem> inventory
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
        boolean noMaterial = materialItemId == null
                && materialItemName == null
                && materialItemDescription == null
                && materialQuantityGained == null
                && materialQuantityAfter == null
                && materialVersion == null;
        boolean completeMaterial = materialItemId != null
                && materialItemName != null
                && materialItemDescription != null
                && materialQuantityGained != null
                && materialQuantityGained > 0
                && materialQuantityAfter != null
                && materialQuantityAfter >= materialQuantityGained
                && materialVersion != null
                && materialVersion > 0;
        if (!noMaterial && !completeMaterial) {
            throw new IllegalArgumentException("Material reward snapshot заполнен частично");
        }
        inventory = inventory == null ? List.of() : List.copyOf(inventory);
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
                pilotProgressPresent,
                pilotLevel,
                pilotCurrentExperience,
                pilotNextLevelExperience,
                petProgressPresent,
                petLevel,
                petBond,
                resolvedChoiceId,
                resolvedChoiceTitle,
                outcomeTitle,
                outcomeSummary,
                null,
                null,
                null,
                null,
                null,
                null,
                List.of()
        );
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

    public HomeRuntimeState withInventory(List<InventoryRuntimeItem> items) {
        return new HomeRuntimeState(
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
                pilotProgressPresent,
                pilotLevel,
                pilotCurrentExperience,
                pilotNextLevelExperience,
                petProgressPresent,
                petLevel,
                petBond,
                resolvedChoiceId,
                resolvedChoiceTitle,
                outcomeTitle,
                outcomeSummary,
                materialItemId,
                materialItemName,
                materialItemDescription,
                materialQuantityGained,
                materialQuantityAfter,
                materialVersion,
                items
        );
    }
}
