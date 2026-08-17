package com.walkingrpg.backend.home.application;

import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

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
import com.walkingrpg.backend.home.domain.ExpeditionDecisionSnapshot;
import com.walkingrpg.backend.home.domain.ExpeditionEventChoiceSnapshot;
import com.walkingrpg.backend.home.domain.ExpeditionEventSnapshot;
import com.walkingrpg.backend.home.domain.ExpeditionJourneyEvent;
import com.walkingrpg.backend.home.domain.ExpeditionSnapshot;
import com.walkingrpg.backend.home.domain.ExpeditionRouteNodeSnapshot;
import com.walkingrpg.backend.home.domain.HomeQuery;
import com.walkingrpg.backend.home.domain.HomeRuntimeState;
import com.walkingrpg.backend.home.domain.InventoryItemSnapshot;
import com.walkingrpg.backend.home.domain.InventoryRuntimeItem;
import com.walkingrpg.backend.home.domain.ItemUpgradeIngredientSnapshot;
import com.walkingrpg.backend.home.domain.ItemUpgradeSnapshot;
import com.walkingrpg.backend.home.domain.MaterialRewardPreviewSnapshot;
import com.walkingrpg.backend.home.domain.PetSnapshot;
import com.walkingrpg.backend.home.domain.PendingEventResultSnapshot;
import com.walkingrpg.backend.home.domain.PilotSnapshot;
import com.walkingrpg.backend.home.infrastructure.HomeReadRepository;
import com.walkingrpg.backend.inventory.application.StarterInventoryContent;
import com.walkingrpg.backend.inventory.domain.InventoryItemDefinition;
import com.walkingrpg.backend.itemupgrade.application.StarterItemUpgradeContent;
import com.walkingrpg.backend.itemupgrade.domain.ItemUpgradeDefinition;
import com.walkingrpg.backend.platform.application.PlatformSkillAccess;
import com.walkingrpg.backend.shared.time.DatabaseSnapshotClock;
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
    private final StarterItemUpgradeContent itemUpgradeContent;
    private final EquipmentRepository equipmentRepository;
    private final StarterEquipmentContent equipmentContent;
    private final ExpeditionContentActivation contentActivation;
    private final PlatformSkillAccess skillAccess;
    private final DatabaseSnapshotClock snapshotClock;

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
            PlatformSkillAccess skillAccess,
            DatabaseSnapshotClock snapshotClock
    ) {
        this.repository = repository;
        this.starterContent = starterContent;
        this.dailyGoalService = dailyGoalService;
        this.expeditionContent = expeditionContent;
        this.inventoryContent = inventoryContent;
        this.craftingContent = craftingContent;
        this.itemUpgradeContent = new StarterItemUpgradeContent(inventoryContent);
        this.equipmentRepository = equipmentRepository;
        this.equipmentContent = equipmentContent;
        this.contentActivation = contentActivation;
        this.skillAccess = skillAccess;
        this.snapshotClock = snapshotClock;
    }

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
            DatabaseSnapshotClock snapshotClock
    ) {
        this(
                repository,
                starterContent,
                dailyGoalService,
                expeditionContent,
                inventoryContent,
                craftingContent,
                equipmentRepository,
                equipmentContent,
                contentActivation,
                PlatformSkillAccess.none(),
                snapshotClock
        );
    }

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
        this(
                repository,
                starterContent,
                dailyGoalService,
                expeditionContent,
                inventoryContent,
                craftingContent,
                equipmentRepository,
                equipmentContent,
                contentActivation,
                PlatformSkillAccess.none(),
                applicationClock(clock)
        );
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
                () -> StarterExpeditionContent
                        .STEADY_STEP_ROUTE_CONTENT_VERSION,
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
        Instant serverTime = snapshotClock.observe();
        String activeContentVersion = expeditionContent.activeContentVersion(
                contentActivation
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
        Set<String> unlockedSkills = skillAccess.unlockedSkills(query.userId());

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
                serverTime,
                activeContentVersion,
                pilotSnapshot(state),
                petSnapshot(state),
                inventorySnapshots(state),
                equipmentSnapshots(equipment),
                pendingEventResult(query.userId(), initialDefinition.expeditionId()),
                expeditionSnapshot(
                        currentDefinition,
                        state,
                        activeContentVersion,
                        unlockedSkills,
                        repository.findJourneyEvents(
                                query.userId(),
                                initialDefinition.expeditionId(),
                                state.expeditionJourneyNumber()
                        )
                ),
                craftingSnapshots(state, activeContentVersion),
                itemUpgradeSnapshots(state, activeContentVersion)
        );
    }

    private static DatabaseSnapshotClock applicationClock(Clock clock) {
        return () -> Instant.now(clock).truncatedTo(ChronoUnit.MICROS);
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
                starter.petId(),
                starter.name(),
                starter.species(),
                state.petLevel(),
                state.petBond(),
                state.petEvolutionStage(),
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
                            runtime.equippedSlotId(),
                            runtime.rarity()
                    );
                })
                .toList();
    }

    private List<ItemUpgradeSnapshot> itemUpgradeSnapshots(
            HomeRuntimeState state,
            String activeContentVersion
    ) {
        Map<String, Long> quantities = new HashMap<>();
        Map<String, Long> uniqueLevels = new HashMap<>();
        state.inventory().forEach(item -> {
            if (item.itemInstanceId() == null) {
                quantities.put(item.itemId(), item.quantity());
            } else {
                uniqueLevels.put(item.itemId(), item.version());
            }
        });
        return itemUpgradeContent.upgrades(activeContentVersion).stream()
                .map(definition -> itemUpgradeSnapshot(
                        definition,
                        quantities,
                        uniqueLevels
                ))
                .toList();
    }

    private ItemUpgradeSnapshot itemUpgradeSnapshot(
            ItemUpgradeDefinition definition,
            Map<String, Long> quantities,
            Map<String, Long> uniqueLevels
    ) {
        Long currentLevel = uniqueLevels.get(
                definition.targetItem().itemId()
        );
        boolean completed = currentLevel != null
                && currentLevel >= definition.resultingLevel();
        boolean ready = currentLevel != null
                && currentLevel == definition.requiredLevel()
                && definition.ingredients().stream().allMatch(
                        ingredient -> quantities.getOrDefault(
                                ingredient.item().itemId(),
                                0L
                        ) >= ingredient.quantity()
                );
        String status = completed
                ? "COMPLETED"
                : currentLevel == null
                ? "LOCKED"
                : ready ? "READY" : "MISSING_MATERIALS";
        return new ItemUpgradeSnapshot(
                definition.upgradeId(),
                definition.upgradeVersion(),
                definition.name(),
                definition.description(),
                status,
                definition.targetItem().itemId(),
                definition.targetItem().name(),
                definition.requiredLevel(),
                definition.resultingLevel(),
                definition.initialRarity().name(),
                definition.resultingRarity().name(),
                definition.ingredients().stream()
                        .map(ingredient -> new ItemUpgradeIngredientSnapshot(
                                ingredient.item().itemId(),
                                ingredient.item().name(),
                                ingredient.quantity(),
                                quantities.getOrDefault(
                                        ingredient.item().itemId(),
                                        0L
                                )
                        ))
                        .toList()
        );
    }

    private List<CraftingRecipeSnapshot> craftingSnapshots(
            HomeRuntimeState state,
            String activeContentVersion
    ) {
        Map<String, Long> quantities = new HashMap<>();
        state.inventory().forEach(item -> quantities.put(
                item.itemId(),
                item.quantity()
        ));
        return craftingContent.recipes(activeContentVersion).stream()
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
            String activeContentVersion,
            Set<String> unlockedSkills,
            List<ExpeditionJourneyEvent> journeyEvents
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
                state.expeditionJourneyNumber(),
                routeTrail(definition, status, journeyEvents),
                decisionLog(journeyEvents),
                eventSnapshot(
                        definition,
                        state,
                        activeContentVersion,
                        unlockedSkills
                )
        );
    }

    private List<ExpeditionRouteNodeSnapshot> routeTrail(
            ExpeditionDefinition currentDefinition,
            String expeditionStatus,
            List<ExpeditionJourneyEvent> journeyEvents
    ) {
        List<ExpeditionRouteNodeSnapshot> trail = new ArrayList<>();
        journeyEvents.forEach(event -> {
            ExpeditionDefinition resolved = expeditionContent.requireEvent(
                    event.eventId()
            );
            trail.add(new ExpeditionRouteNodeSnapshot(
                    resolved.currentNodeId(),
                    resolved.currentNodeName(),
                    "VISITED"
            ));
        });

        String terminalState = ExpeditionProgressStatus.COMPLETED.name().equals(
                expeditionStatus
        ) ? "COMPLETED" : "CURRENT";
        ExpeditionRouteNodeSnapshot terminal = new ExpeditionRouteNodeSnapshot(
                currentDefinition.currentNodeId(),
                currentDefinition.currentNodeName(),
                terminalState
        );
        if (!trail.isEmpty()
                && trail.getLast().nodeId().equals(terminal.nodeId())) {
            trail.set(trail.size() - 1, terminal);
        } else {
            trail.add(terminal);
        }
        return List.copyOf(trail);
    }

    private List<ExpeditionDecisionSnapshot> decisionLog(
            List<ExpeditionJourneyEvent> journeyEvents
    ) {
        return journeyEvents.stream()
                .map(event -> new ExpeditionDecisionSnapshot(
                        event.eventId(),
                        event.eventTitle(),
                        event.choiceId(),
                        event.choiceTitle(),
                        event.outcomeTitle(),
                        event.outcomeSummary(),
                        event.pilotExperienceGained(),
                        event.petId(),
                        event.petName(),
                        event.petBondGained(),
                        event.materialReward(),
                        event.resolvedAt()
                ))
                .toList();
    }

    private ExpeditionEventSnapshot eventSnapshot(
            ExpeditionDefinition definition,
            HomeRuntimeState state,
            String activeContentVersion,
            Set<String> unlockedSkills
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
                .eventChoices(state.unlockedEventId(), activeContentVersion)
                .stream()
                .map(choice -> choiceSnapshot(
                        choice,
                        state.inventory(),
                        state.petId(),
                        state.petEvolutionStage(),
                        unlockedSkills
                ))
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
            List<InventoryRuntimeItem> inventory,
            String activePetId,
            int activePetEvolutionStage,
            Set<String> unlockedSkills
    ) {
        MaterialRewardPreviewSnapshot material = choice.materialReward() == null
                ? null
                : new MaterialRewardPreviewSnapshot(
                        choice.materialReward().item().itemId(),
                        choice.materialReward().item().name(),
                        choice.materialReward().quantity()
                );
        var equipmentRequirement = choice.equipmentRequirement();
        var petRequirement = choice.petRequirement();
        var skillRequirement = choice.skillRequirement();
        boolean available = true;
        ExpeditionChoiceRequirementSnapshot requirementSnapshot = null;
        if (equipmentRequirement != null) {
            available = inventory.stream()
                    .anyMatch(item -> equipmentRequirement.slotId().equals(
                                    item.equippedSlotId()
                            )
                            && equipmentRequirement.item().itemId().equals(
                                    item.itemId()
                            )
                            && item.version() >= equipmentRequirement
                                    .minimumUpgradeLevel());
            requirementSnapshot = new ExpeditionChoiceRequirementSnapshot(
                    "EQUIPPED_ITEM",
                    equipmentRequirement.slotId(),
                    equipmentRequirement.slotName(),
                    equipmentRequirement.item().itemId(),
                    equipmentRequirement.item().name(),
                    equipmentRequirement.minimumUpgradeLevel(),
                    0,
                    equipmentRequirement.lockedReason()
            );
        } else if (petRequirement != null) {
            available = petRequirement.petId().equals(activePetId)
                    && activePetEvolutionStage
                    >= petRequirement.minimumEvolutionStage();
            requirementSnapshot = new ExpeditionChoiceRequirementSnapshot(
                    "ACTIVE_PET",
                    "ACTIVE_PET",
                    "Активный питомец",
                    petRequirement.petId(),
                    petRequirement.petName(),
                    1,
                    petRequirement.minimumEvolutionStage(),
                    petRequirement.lockedReason()
            );
        } else if (skillRequirement != null) {
            available = unlockedSkills.contains(skillRequirement.skillId());
            requirementSnapshot = new ExpeditionChoiceRequirementSnapshot(
                    "UNLOCKED_SKILL",
                    "PILOT_SKILL",
                    "Навык пилота",
                    skillRequirement.skillId(),
                    skillRequirement.skillName(),
                    1,
                    0,
                    skillRequirement.lockedReason()
            );
        }
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
