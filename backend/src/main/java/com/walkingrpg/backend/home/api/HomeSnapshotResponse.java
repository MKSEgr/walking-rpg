package com.walkingrpg.backend.home.api;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

import com.walkingrpg.backend.home.domain.DailyGoalPolicySnapshot;
import com.walkingrpg.backend.home.domain.CraftingRecipeSnapshot;
import com.walkingrpg.backend.home.domain.EquipmentSlotSnapshot;
import com.walkingrpg.backend.home.domain.ExpeditionSnapshot;
import com.walkingrpg.backend.home.domain.InventoryItemSnapshot;
import com.walkingrpg.backend.home.domain.ItemUpgradeSnapshot;
import com.walkingrpg.backend.home.domain.PetSnapshot;
import com.walkingrpg.backend.home.domain.PendingEventResultSnapshot;
import com.walkingrpg.backend.home.domain.PilotSnapshot;
import com.walkingrpg.backend.home.domain.WeeklyActivityRhythmSnapshot;

public record HomeSnapshotResponse(
        LocalDate localDate,
        String timeZone,
        long dailySteps,
        long dailyGoal,
        DailyGoalPolicySnapshot dailyGoalPolicy,
        WeeklyActivityRhythmSnapshot weeklyActivityRhythm,
        long availableEnergy,
        long activityStateVersion,
        long economyVersion,
        Instant lastActivitySyncAt,
        Instant serverTime,
        String contentVersion,
        PilotSnapshot pilot,
        PetSnapshot pet,
        List<InventoryItemSnapshot> inventory,
        List<EquipmentSlotSnapshot> equipment,
        PendingEventResultSnapshot pendingEventResult,
        ExpeditionSnapshot expedition,
        List<CraftingRecipeSnapshot> craftingRecipes,
        List<ItemUpgradeSnapshot> itemUpgrades
) {
    public HomeSnapshotResponse {
        inventory = inventory == null ? List.of() : List.copyOf(inventory);
        equipment = equipment == null ? List.of() : List.copyOf(equipment);
        craftingRecipes = craftingRecipes == null
                ? List.of()
                : List.copyOf(craftingRecipes);
        itemUpgrades = itemUpgrades == null
                ? List.of()
                : List.copyOf(itemUpgrades);
    }

    public HomeSnapshotResponse(
            LocalDate localDate,
            String timeZone,
            long dailySteps,
            long dailyGoal,
            DailyGoalPolicySnapshot dailyGoalPolicy,
            WeeklyActivityRhythmSnapshot weeklyActivityRhythm,
            long availableEnergy,
            long activityStateVersion,
            long economyVersion,
            Instant lastActivitySyncAt,
            Instant serverTime,
            String contentVersion,
            PilotSnapshot pilot,
            PetSnapshot pet,
            ExpeditionSnapshot expedition
    ) {
        this(
                localDate,
                timeZone,
                dailySteps,
                dailyGoal,
                dailyGoalPolicy,
                weeklyActivityRhythm,
                availableEnergy,
                activityStateVersion,
                economyVersion,
                lastActivitySyncAt,
                serverTime,
                contentVersion,
                pilot,
                pet,
                List.of(),
                List.of(),
                null,
                expedition,
                List.of(),
                List.of()
        );
    }
}
