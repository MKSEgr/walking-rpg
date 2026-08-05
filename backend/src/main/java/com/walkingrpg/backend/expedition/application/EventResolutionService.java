package com.walkingrpg.backend.expedition.application;

import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Optional;
import java.util.UUID;

import com.walkingrpg.backend.equipment.application.EquipmentService;
import com.walkingrpg.backend.equipment.application.StarterEquipmentContent;
import com.walkingrpg.backend.equipment.infrastructure.InMemoryEquipmentRepository;
import com.walkingrpg.backend.expedition.domain.ExpeditionChoiceEquipmentRequirement;
import com.walkingrpg.backend.expedition.domain.EventIdempotencyScope;
import com.walkingrpg.backend.expedition.domain.EventMaterialRewardResult;
import com.walkingrpg.backend.expedition.domain.EventNextNodeResult;
import com.walkingrpg.backend.expedition.domain.EventPetRewardResult;
import com.walkingrpg.backend.expedition.domain.EventPilotRewardResult;
import com.walkingrpg.backend.expedition.domain.EventResolutionCommand;
import com.walkingrpg.backend.expedition.domain.EventResolutionFingerprint;
import com.walkingrpg.backend.expedition.domain.EventResolutionResult;
import com.walkingrpg.backend.expedition.domain.EventResolutionStatus;
import com.walkingrpg.backend.expedition.domain.ExpeditionDefinition;
import com.walkingrpg.backend.expedition.domain.ExpeditionEventChoiceDefinition;
import com.walkingrpg.backend.expedition.domain.ExpeditionProgressState;
import com.walkingrpg.backend.expedition.domain.ExpeditionProgressStatus;
import com.walkingrpg.backend.expedition.domain.ProcessedEventResolution;
import com.walkingrpg.backend.expedition.infrastructure.EventResolutionRepository;
import com.walkingrpg.backend.expedition.infrastructure.ExpeditionRepository;
import com.walkingrpg.backend.inventory.application.InventoryService;
import com.walkingrpg.backend.inventory.domain.InventoryRewardResult;
import com.walkingrpg.backend.progression.application.ProgressionService;
import com.walkingrpg.backend.progression.domain.ProgressionRewardResult;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class EventResolutionService {

    private final ExpeditionRepository expeditionRepository;
    private final EventResolutionRepository eventRepository;
    private final ProgressionService progressionService;
    private final InventoryService inventoryService;
    private final StarterExpeditionContent content;
    private final EquipmentService equipmentService;
    private final ExpeditionContentActivation contentActivation;
    private final Clock clock;

    @Autowired
    public EventResolutionService(
            ExpeditionRepository expeditionRepository,
            EventResolutionRepository eventRepository,
            ProgressionService progressionService,
            InventoryService inventoryService,
            StarterExpeditionContent content,
            EquipmentService equipmentService,
            ExpeditionContentActivation contentActivation,
            Clock clock
    ) {
        this.expeditionRepository = expeditionRepository;
        this.eventRepository = eventRepository;
        this.progressionService = progressionService;
        this.inventoryService = inventoryService;
        this.content = content;
        this.equipmentService = equipmentService;
        this.contentActivation = contentActivation;
        this.clock = clock;
    }

    public EventResolutionService(
            ExpeditionRepository expeditionRepository,
            EventResolutionRepository eventRepository,
            ProgressionService progressionService,
            InventoryService inventoryService,
            StarterExpeditionContent content,
            EquipmentService equipmentService,
            Clock clock
    ) {
        this(
                expeditionRepository,
                eventRepository,
                progressionService,
                inventoryService,
                content,
                equipmentService,
                ignored -> true,
                clock
        );
    }

    public EventResolutionService(
            ExpeditionRepository expeditionRepository,
            EventResolutionRepository eventRepository,
            ProgressionService progressionService,
            InventoryService inventoryService,
            StarterExpeditionContent content,
            Clock clock
    ) {
        this(
                expeditionRepository,
                eventRepository,
                progressionService,
                inventoryService,
                content,
                new EquipmentService(
                        new InMemoryEquipmentRepository(),
                        new StarterEquipmentContent(),
                        expeditionRepository,
                        eventRepository,
                        clock
                ),
                ignored -> true,
                clock
        );
    }

    @Transactional
    public EventResolutionResult resolve(EventResolutionCommand command) {
        return resolveInternal(command, true);
    }

    @Transactional
    public EventResolutionResult resolve(
            EventResolutionCommand command,
            boolean handoffRequired
    ) {
        return resolveInternal(command, handoffRequired);
    }

    private EventResolutionResult resolveInternal(
            EventResolutionCommand command,
            boolean handoffRequired
    ) {
        ExpeditionDefinition definition = content.requireEvent(command.eventId());
        expeditionRepository.acquireLock(command.userId(), definition.expeditionId());
        Instant serverTime = Instant.now(clock).truncatedTo(ChronoUnit.MICROS);

        EventIdempotencyScope scope = EventIdempotencyScope.from(command);
        String fingerprint = EventResolutionFingerprint.sha256(command);
        ProcessedEventResolution processed = eventRepository.findProcessed(scope)
                .orElse(null);
        if (processed != null) {
            if (!processed.requestFingerprint().equals(fingerprint)) {
                throw new EventResolutionIdempotencyConflictException();
            }
            return processed.result();
        }
        requireNoPendingResult(command.userId(), definition.expeditionId());
        boolean resonanceRouteActive = contentActivation.isActive(
                StarterExpeditionContent.CONTENT_VERSION
        );

        ExpeditionProgressState current = expeditionRepository.findState(
                command.userId(),
                definition.expeditionId()
        ).orElseThrow(() -> new EventStateConflictException(
                "Событие ещё не открыто",
                "NOT_STARTED"
        ));
        validateOpenEvent(current, command.eventId());
        ExpeditionEventChoiceDefinition choice = content.requireChoice(
                command.eventId(),
                command.choiceId(),
                resonanceRouteActive
        );
        requireEquipment(command.userId(), choice);

        ProgressionRewardResult progression = progressionService.rewardEvent(
                command.userId(),
                choice.pilotExperienceReward(),
                choice.petBondReward(),
                serverTime
        );
        EventMaterialRewardResult material = materialReward(
                command.userId(),
                scope,
                choice,
                serverTime
        );
        Optional<ExpeditionDefinition> nextNode = content.nextNodeAfterEvent(
                command.eventId(),
                choice.choiceId(),
                resonanceRouteActive
        );
        ExpeditionProgressState updated = nextNode
                .map(node -> current.resolveAndContinue(command.eventId(), node))
                .orElseGet(() -> current.resolveAndComplete(command.eventId()));

        EventResolutionResult result = new EventResolutionResult(
                UUID.randomUUID(),
                content.contentVersion(resonanceRouteActive),
                definition.expeditionId(),
                updated.status(),
                updated.version(),
                command.eventId(),
                definition.event().title(),
                EventResolutionStatus.RESOLVED,
                choice.choiceId(),
                choice.title(),
                choice.outcomeTitle(),
                choice.outcomeSummary(),
                new EventPilotRewardResult(
                        progression.pilotDefinition().pilotId(),
                        progression.pilotDefinition().name(),
                        progression.pilot().level(),
                        progression.pilotExperienceGained(),
                        progression.pilot().currentExperience(),
                        progression.pilot().nextLevelExperience(),
                        progression.pilot().version()
                ),
                new EventPetRewardResult(
                        progression.petDefinition().petId(),
                        progression.petDefinition().name(),
                        progression.pet().level(),
                        progression.petBondGained(),
                        progression.pet().bond(),
                        progression.pet().version()
                ),
                material,
                handoffRequired,
                nextNode.map(node -> new EventNextNodeResult(
                        node.currentNodeId(),
                        node.currentNodeName()
                )).orElse(null),
                serverTime
        );

        expeditionRepository.saveState(
                command.userId(),
                definition.expeditionId(),
                updated,
                serverTime
        );
        eventRepository.saveProcessed(
                scope,
                new ProcessedEventResolution(fingerprint, result)
        );
        return result;
    }

    private void requireNoPendingResult(String userId, String expeditionId) {
        eventRepository.findPendingResult(userId, expeditionId)
                .ifPresent(pending -> {
                    EventResolutionResult result = pending.result();
                    throw new PendingEventResultException(
                            result.receiptId(),
                            result.eventId()
                    );
                });
    }

    private EventMaterialRewardResult materialReward(
            String userId,
            EventIdempotencyScope scope,
            ExpeditionEventChoiceDefinition choice,
            Instant serverTime
    ) {
        if (choice.materialReward() == null) {
            return null;
        }
        InventoryRewardResult reward = inventoryService.rewardEventMaterial(
                userId,
                choice.materialReward(),
                inventorySourceKey(scope),
                serverTime
        );
        return new EventMaterialRewardResult(
                reward.item().itemId(),
                reward.item().name(),
                reward.item().description(),
                reward.quantityGained(),
                reward.quantityAfter(),
                reward.version()
        );
    }

    private void validateOpenEvent(ExpeditionProgressState state, String eventId) {
        if (state.status() != ExpeditionProgressStatus.EVENT_READY) {
            throw new EventStateConflictException(
                    state.status() == ExpeditionProgressStatus.COMPLETED
                            ? "Событие уже разрешено"
                            : "Событие ещё не готово к разрешению",
                    state.status().name()
            );
        }
        if (!eventId.equals(state.unlockedEventId())) {
            throw new EventStateConflictException(
                    "Запрошенное событие не открыто для пользователя",
                    state.status().name()
            );
        }
    }

    private void requireEquipment(
            String userId,
            ExpeditionEventChoiceDefinition choice
    ) {
        ExpeditionChoiceEquipmentRequirement requirement =
                choice.equipmentRequirement();
        if (requirement == null) {
            return;
        }
        if (!equipmentService.isEquipped(
                userId,
                requirement.slotId(),
                requirement.item().itemId()
        )) {
            throw new EventChoiceUnavailableException(
                    choice.choiceId(),
                    requirement.slotId(),
                    requirement.item().itemId()
            );
        }
    }

    private String inventorySourceKey(EventIdempotencyScope scope) {
        return scope.eventId().length()
                + ":"
                + scope.eventId()
                + ":"
                + scope.idempotencyKey();
    }
}
