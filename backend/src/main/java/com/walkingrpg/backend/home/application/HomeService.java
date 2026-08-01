package com.walkingrpg.backend.home.application;

import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import com.walkingrpg.backend.crafting.application.StarterCraftingContent;
import com.walkingrpg.backend.crafting.domain.CraftingRecipeDefinition;
import com.walkingrpg.backend.equipment.application.StarterEquipmentContent;
import com.walkingrpg.backend.equipment.domain.EquipmentSlotDefinition;
import com.walkingrpg.backend.equipment.domain.EquipmentSlotState;
import com.walkingrpg.backend.equipment.infrastructure.EquipmentRepository;
import com.walkingrpg.backend.equipment.infrastructure.InMemoryEquipmentRepository;
import com.walkingrpg.backend.expedition.application.ExpeditionContentActivation;
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
import com.walkingrpg.backend.home.domain.EquipmentItemSnapshot;
import com.walkingrpg.backend.home.domain.EquipmentSlotSnapshot;
import com.walkingrpg.backend.home.domain.ExpeditionChoiceRequirementSnapshot;
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
    private final EquipmentRepository equipmentRepository;
    private final StarterEquipmentContent equipmentContent;
    private final ExpeditionContentActivation contentActivation;
    private final Clock clock;

    @Autowired
    public HomeService(
            HomeReadRepository repository,
            StarterHomeContent starterContent,
            DailyGoalService dailyGoalService,
            StarterExpeditionContent expeditionContent,
            StarterInventoryContent inventoryContent,
            StarterCraftingContent craftingContent,
            EquipmentRepository equipmentRepository,
            StarterEquipmentContent equipmentContent,
            ExpeditionContentActivation contentActivation,
            Clock clock
    ) {
        this.repository = repository;
        this.starterContent = starterContent;
        this.dailyGoalService = dailyGoalService;
        this.expeditionContent = expeditionContent;
        this.inventoryContent = inventoryContent;
        this.craftingContent = craftingContent;
        this.equipmentRepository = equipmentRepository;
        this.equipmentContent = equipmentContent;
        this.contentActivation = contentActivation;
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
                new InMemoryEquipmentRepository(),
                new StarterEquipmentContent(),
                ignored -> true,
                clock
        );
    }

    public HomeService(
            HomeReadRepository repository,
            StarterHomeContent starterContent,
            DailyGoalService dailyGoalService,
            StarterExpeditionContent expeditionContent,
            ExpeditionContentActivation contentActivation,
            Clock clock
    ) {
        this(
                repository,
                starterContent,
                dailyGoalService,
                expeditionContent,
                new StarterInventoryContent(),
                new StarterCraftingContent(),
                new InMemoryEquipmentRepository(),
                new StarterEquipmentContent(),
                contentActivation,
                clock
        );
    }

    @Transactional(readOnly = true, isolation = Isolation.REPEATABLE_READ)
    public HomeSnapshotResponse getSnapshot(HomeQuery query) {
        boolean resonanceRouteActive = contentActivation.isActive(
                StarterExpeditionContent.CONTENT_VERSION
        );
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
        List<EquipmentSlotState> equipment = equipmentStates(query.userId());

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
                expeditionContent.contentVersion(resonanceRouteActive),
                pilotSnapshot(state),
                petSnapshot(state),
                inventorySnapshots(state),
                equipmentSnapshots(equipment),
                pendingEventResult(query.userId(), initialDefinition.expeditionId()),
                expeditionSnapshot(
                        currentDefinition,
                        state,
                        equipment,
                        resonanceRouteActive
                ),
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
                            item.kind().name(),
                            runtime.itemInstanceId(),
                            equipmentContent.slotForItem(item.itemId())
                                    .map(EquipmentSlotDefinition::slotId)
                                    .orElse(null),
                            runtime.equippedSlotId()
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
            HomeRuntimeState state,
            List<EquipmentSlotState> equipment,
            boolean resonanceRouteActive
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
                eventSnapshot(
                        definition,
                        state,
                        equipment,
                        resonanceRouteActive
                )
        );
    }

    private ExpeditionEventSnapshot eventSnapshot(
            ExpeditionDefinition definition,
            HomeRuntimeState state,
            List<EquipmentSlotState> equipment,
            boolean resonanceRouteActive
    ) {
        if (state.unlockedEventId() == null) {
            return null;
        }
        if (ExpeditionProgressStatus.COMPLETED.name().equals(
                state.expeditionStatus()
        )) {
            return null;
        }
        List<ExpeditionEventChoiceSnapshot> projectedChoices = expeditionContent
                .eventChoices(state.unlockedEventId(), resonanceRouteActive)
                .stream()
                .map(choice -> choiceSnapshot(choice, equipment))
                .toList();
        List<ExpeditionEventChoiceSnapshot> choices = projectedChoices.stream()
                .filter(choice -> "AVAILABLE".equals(choice.availability()))
                .toList();
        List<ExpeditionEventChoiceSnapshot> lockedChoices = projectedChoices.stream()
                .filter(choice -> "LOCKED".equals(choice.availability()))
                .toList();
        return new ExpeditionEventSnapshot(
                definition.event().eventId(),
                definition.event().title(),
                definition.event().summary(),
                "READY",
                choices,
                lockedChoices,
                null,
                null,
                null,
                null,
                null
        );
    }

    private ExpeditionEventChoiceSnapshot choiceSnapshot(
            ExpeditionEventChoiceDefinition choice,
            List<EquipmentSlotState> equipment
    ) {
        MaterialRewardPreviewSnapshot material = choice.materialReward() == null
                ? null
                : new MaterialRewardPreviewSnapshot(
                        choice.materialReward().item().itemId(),
                        choice.materialReward().item().name(),
                        choice.materialReward().quantity()
                );
        var requirement = choice.equipmentRequirement();
        boolean available = requirement == null || equipment.stream()
                .anyMatch(slot -> requirement.slotId().equals(slot.slotId())
                        && requirement.item().itemId().equals(slot.itemId()));
        ExpeditionChoiceRequirementSnapshot requirementSnapshot =
                requirement == null
                        ? null
                        : new ExpeditionChoiceRequirementSnapshot(
                                "EQUIPPED_ITEM",
                                requirement.slotId(),
                                requirement.slotName(),
                                requirement.item().itemId(),
                                requirement.item().name(),
                                requirement.lockedReason()
                        );
        return new ExpeditionEventChoiceSnapshot(
                choice.choiceId(),
                choice.title(),
                choice.description(),
                choice.pilotExperienceReward(),
                choice.petBondReward(),
                material,
                available ? "AVAILABLE" : "LOCKED",
                requirementSnapshot
        );
    }

    private List<EquipmentSlotState> equipmentStates(String userId) {
        Map<String, EquipmentSlotState> states = new HashMap<>();
        equipmentRepository.findAll(userId).forEach(state -> states.put(
                state.slotId(),
                state
        ));
        return equipmentContent.slots().stream()
                .map(slot -> states.getOrDefault(
                        slot.slotId(),
                        EquipmentSlotState.empty(slot.slotId())
                ))
                .toList();
    }

    private List<EquipmentSlotSnapshot> equipmentSnapshots(
            List<EquipmentSlotState> states
    ) {
        Map<String, EquipmentSlotState> bySlot = new HashMap<>();
        states.forEach(state -> bySlot.put(state.slotId(), state));
        return equipmentContent.slots().stream()
                .map(slot -> equipmentSnapshot(
                        slot,
                        bySlot.getOrDefault(
                                slot.slotId(),
                                EquipmentSlotState.empty(slot.slotId())
                        )
                ))
                .toList();
    }

    private EquipmentSlotSnapshot equipmentSnapshot(
            EquipmentSlotDefinition slot,
            EquipmentSlotState state
    ) {
        EquipmentItemSnapshot item = null;
        if (state.isEquipped()) {
            InventoryItemDefinition definition = inventoryContent.findOrFallback(
                    state.itemId()
            );
            item = new EquipmentItemSnapshot(
                    state.itemInstanceId(),
                    definition.itemId(),
                    definition.name(),
                    definition.description()
            );
        }
        return new EquipmentSlotSnapshot(
                slot.slotId(),
                slot.name(),
                slot.description(),
                state.isEquipped() ? "EQUIPPED" : "EMPTY",
                state.version(),
                item
        );
    }

}
