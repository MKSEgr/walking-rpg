package com.walkingrpg.backend.home.application;

import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import com.walkingrpg.backend.crafting.application.StarterCraftingContent;
import com.walkingrpg.backend.crafting.domain.CraftingRecipeDefinition;
import com.walkingrpg.backend.expedition.application.StarterExpeditionContent;
import com.walkingrpg.backend.expedition.domain.ExpeditionDefinition;
import com.walkingrpg.backend.expedition.domain.ExpeditionEventChoiceDefinition;
import com.walkingrpg.backend.expedition.domain.ExpeditionProgressStatus;
import com.walkingrpg.backend.expedition.domain.ProcessedEventResolution;
import com.walkingrpg.backend.goal.application.DailyGoalService;
import com.walkingrpg.backend.goal.domain.DailyGoal;
import com.walkingrpg.backend.home.api.HomeSnapshotResponse;
import com.walkingrpg.backend.home.domain.DailyGoalPolicySnapshot;
import com.walkingrpg.backend.home.domain.CraftingIngredientSnapshot;
import com.walkingrpg.backend.home.domain.CraftingRecipeSnapshot;
import com.walkingrpg.backend.home.domain.CraftingResultPreviewSnapshot;
import com.walkingrpg.backend.home.domain.ExpeditionEventChoiceSnapshot;
import com.walkingrpg.backend.home.domain.ExpeditionEventSnapshot;
import com.walkingrpg.backend.home.domain.ExpeditionSnapshot;
import com.walkingrpg.backend.home.domain.HomeQuery;
import com.walkingrpg.backend.home.domain.HomeRuntimeState;
import com.walkingrpg.backend.home.domain.InventoryItemSnapshot;
import com.walkingrpg.backend.home.domain.MaterialRewardPreviewSnapshot;
import com.walkingrpg.backend.home.domain.PetSnapshot;
import com.walkingrpg.backend.home.domain.PendingEventResultSnapshot;
import com.walkingrpg.backend.home.domain.PilotSnapshot;
import com.walkingrpg.backend.home.infrastructure.HomeReadRepository;
import com.walkingrpg.backend.inventory.application.StarterInventoryContent;
import com.walkingrpg.backend.inventory.domain.InventoryItemDefinition;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;

@Service
public class HomeService {

    private final HomeReadRepository repository;
    private final StarterHomeContent starterContent;
    private final DailyGoalService dailyGoalService;
    private final StarterExpeditionContent expeditionContent;
    private final StarterInventoryContent inventoryContent;
    private final StarterCraftingContent craftingContent;
    private final Clock clock;

    @Autowired
    public HomeService(
            HomeReadRepository repository,
            StarterHomeContent starterContent,
            DailyGoalService dailyGoalService,
            StarterExpeditionContent expeditionContent,
            StarterInventoryContent inventoryContent,
            StarterCraftingContent craftingContent,
            Clock clock
    ) {
        this.repository = repository;
        this.starterContent = starterContent;
        this.dailyGoalService = dailyGoalService;
        this.expeditionContent = expeditionContent;
        this.inventoryContent = inventoryContent;
        this.craftingContent = craftingContent;
        this.clock = clock;
    }

    public HomeService(
            HomeReadRepository repository,
            StarterHomeContent starterContent,
            DailyGoalService dailyGoalService,
            StarterExpeditionContent expeditionContent,
            Clock clock
    ) {
        this(
                repository,
                starterContent,
                dailyGoalService,
                expeditionContent,
                new StarterInventoryContent(),
                new StarterCraftingContent(),
                clock
        );
    }

    @Transactional(readOnly = true, isolation = Isolation.REPEATABLE_READ)
    public HomeSnapshotResponse getSnapshot(HomeQuery query) {
        ExpeditionDefinition initialDefinition = expeditionContent.initialDefinition();
        DailyGoal dailyGoal = dailyGoalService.calculate(
                query.userId(),
                query.localDate()
        );
        HomeRuntimeState state = repository.findState(
                query.userId(),
                query.localDate(),
                initialDefinition.expeditionId()
        );
        ExpeditionDefinition currentDefinition = state.currentNodeId() == null
                ? initialDefinition
                : expeditionContent.requireNode(state.currentNodeId());

        return new HomeSnapshotResponse(
                query.localDate(),
                state.timeZone(),
                state.dailySteps(),
                dailyGoal.steps(),
                DailyGoalPolicySnapshot.from(dailyGoal),
                state.availableEnergy(),
                state.activityStateVersion(),
                state.economyVersion(),
                state.lastActivitySyncAt(),
                Instant.now(clock).truncatedTo(ChronoUnit.MICROS),
                expeditionContent.contentVersion(),
                pilotSnapshot(state),
                petSnapshot(state),
                inventorySnapshots(state),
                pendingEventResult(query.userId(), initialDefinition.expeditionId()),
                expeditionSnapshot(currentDefinition, state),
                craftingSnapshots(state)
        );
    }

    private PendingEventResultSnapshot pendingEventResult(
            String userId,
            String expeditionId
    ) {
        return repository.findPendingEventResult(userId, expeditionId)
                .map(ProcessedEventResolution::result)
                .map(result -> new PendingEventResultSnapshot(
                        result.receiptId(),
                        result.eventId(),
                        result.eventTitle(),
                        result.choiceId(),
                        result.choiceTitle(),
                        result.outcomeTitle(),
                        result.outcomeSummary(),
                        result.pilot(),
                        result.pet(),
                        result.material(),
                        result.nextNode(),
                        result.serverTime()
                ))
                .orElse(null);
    }

    private PilotSnapshot pilotSnapshot(HomeRuntimeState state) {
        PilotSnapshot starter = starterContent.pilot();
        if (!state.pilotProgressPresent()) {
            return starter;
        }
        return new PilotSnapshot(
                starter.name(),
                state.pilotLevel(),
                state.pilotCurrentExperience(),
                state.pilotNextLevelExperience(),
                starter.specialization()
        );
    }

    private PetSnapshot petSnapshot(HomeRuntimeState state) {
        PetSnapshot starter = starterContent.pet(state.petId());
        if (!state.petProgressPresent()) {
            return starter;
        }
        return new PetSnapshot(
                starter.name(),
                starter.species(),
                state.petLevel(),
                state.petBond(),
                starter.trait()
        );
    }

    private List<InventoryItemSnapshot> inventorySnapshots(HomeRuntimeState state) {
        return state.inventory().stream()
                .map(runtime -> {
                    InventoryItemDefinition item = inventoryContent.findOrFallback(
                            runtime.itemId()
                    );
                    return new InventoryItemSnapshot(
                            item.itemId(),
                            item.name(),
                            item.description(),
                            runtime.quantity(),
                            runtime.version(),
                            item.kind().name()
                    );
                })
                .toList();
    }

    private List<CraftingRecipeSnapshot> craftingSnapshots(
            HomeRuntimeState state
    ) {
        Map<String, Long> quantities = new HashMap<>();
        state.inventory().forEach(item -> quantities.put(
                item.itemId(),
                item.quantity()
        ));
        return craftingContent.recipes().stream()
                .map(recipe -> craftingSnapshot(recipe, quantities))
                .toList();
    }

    private CraftingRecipeSnapshot craftingSnapshot(
            CraftingRecipeDefinition recipe,
            Map<String, Long> quantities
    ) {
        boolean crafted = quantities.getOrDefault(
                recipe.resultItem().itemId(),
                0L
        ) > 0;
        boolean ready = !crafted && recipe.ingredients().stream()
                .allMatch(ingredient -> quantities.getOrDefault(
                        ingredient.item().itemId(),
                        0L
                ) >= ingredient.quantity());
        String status = crafted
                ? "CRAFTED"
                : ready ? "READY" : "MISSING_MATERIALS";
        return new CraftingRecipeSnapshot(
                recipe.recipeId(),
                recipe.recipeVersion(),
                recipe.name(),
                recipe.description(),
                status,
                recipe.ingredients().stream()
                        .map(ingredient -> new CraftingIngredientSnapshot(
                                ingredient.item().itemId(),
                                ingredient.item().name(),
                                ingredient.quantity(),
                                quantities.getOrDefault(
                                        ingredient.item().itemId(),
                                        0L
                                )
                        ))
                        .toList(),
                new CraftingResultPreviewSnapshot(
                        recipe.resultItem().itemId(),
                        recipe.resultItem().name(),
                        recipe.resultItem().description(),
                        recipe.resultItem().kind().name()
                )
        );
    }

    private ExpeditionSnapshot expeditionSnapshot(
            ExpeditionDefinition definition,
            HomeRuntimeState state
    ) {
        long requiredEnergy = state.expeditionRequiredEnergy() > 0
                ? state.expeditionRequiredEnergy()
                : definition.requiredEnergy();
        String status = state.expeditionStatus() == null
                ? ExpeditionProgressStatus.IN_PROGRESS.name()
                : state.expeditionStatus();

        return new ExpeditionSnapshot(
                definition.expeditionId(),
                definition.name(),
                state.currentNodeId() == null
                        ? definition.currentNodeId()
                        : state.currentNodeId(),
                definition.currentNodeName(),
                state.expeditionProgress(),
                requiredEnergy,
                status,
                state.expeditionVersion(),
                eventSnapshot(definition, state)
        );
    }

    private ExpeditionEventSnapshot eventSnapshot(
            ExpeditionDefinition definition,
            HomeRuntimeState state
    ) {
        if (state.unlockedEventId() == null) {
            return null;
        }
        if (ExpeditionProgressStatus.COMPLETED.name().equals(
                state.expeditionStatus()
        )) {
            return null;
        }
        List<ExpeditionEventChoiceSnapshot> choices = expeditionContent
                .eventChoices(state.unlockedEventId())
                .stream()
                .map(this::choiceSnapshot)
                .toList();
        return new ExpeditionEventSnapshot(
                definition.event().eventId(),
                definition.event().title(),
                definition.event().summary(),
                "READY",
                choices,
                null,
                null,
                null,
                null,
                null
        );
    }

    private ExpeditionEventChoiceSnapshot choiceSnapshot(
            ExpeditionEventChoiceDefinition choice
    ) {
        MaterialRewardPreviewSnapshot material = choice.materialReward() == null
                ? null
                : new MaterialRewardPreviewSnapshot(
                        choice.materialReward().item().itemId(),
                        choice.materialReward().item().name(),
                        choice.materialReward().quantity()
                );
        return new ExpeditionEventChoiceSnapshot(
                choice.choiceId(),
                choice.title(),
                choice.description(),
                choice.pilotExperienceReward(),
                choice.petBondReward(),
                material
        );
    }

}
