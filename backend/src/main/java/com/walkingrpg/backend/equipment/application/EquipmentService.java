package com.walkingrpg.backend.equipment.application;

import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import com.walkingrpg.backend.equipment.domain.EquipmentAction;
import com.walkingrpg.backend.equipment.domain.EquipmentCommand;
import com.walkingrpg.backend.equipment.domain.EquipmentFingerprint;
import com.walkingrpg.backend.equipment.domain.EquipmentIdempotencyScope;
import com.walkingrpg.backend.equipment.domain.EquipmentResult;
import com.walkingrpg.backend.equipment.domain.EquipmentSlotDefinition;
import com.walkingrpg.backend.equipment.domain.EquipmentSlotState;
import com.walkingrpg.backend.equipment.domain.ProcessedEquipmentCommand;
import com.walkingrpg.backend.equipment.domain.UniqueInventoryItemReference;
import com.walkingrpg.backend.equipment.infrastructure.EquipmentRepository;
import com.walkingrpg.backend.expedition.application.PendingEventResultException;
import com.walkingrpg.backend.expedition.application.StarterExpeditionContent;
import com.walkingrpg.backend.expedition.domain.ProcessedEventResolution;
import com.walkingrpg.backend.expedition.infrastructure.EventResolutionRepository;
import com.walkingrpg.backend.expedition.infrastructure.ExpeditionRepository;
import com.walkingrpg.backend.inventory.domain.InventoryItemDefinition;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class EquipmentService {

    private final EquipmentRepository repository;
    private final StarterEquipmentContent content;
    private final ExpeditionRepository expeditionRepository;
    private final EventResolutionRepository eventResolutionRepository;
    private final Clock clock;

    public EquipmentService(
            EquipmentRepository repository,
            StarterEquipmentContent content,
            ExpeditionRepository expeditionRepository,
            EventResolutionRepository eventResolutionRepository,
            Clock clock
    ) {
        this.repository = repository;
        this.content = content;
        this.expeditionRepository = expeditionRepository;
        this.eventResolutionRepository = eventResolutionRepository;
        this.clock = clock;
    }

    @Transactional
    public EquipmentResult change(EquipmentCommand command) {
        repository.acquireLock(command.userId());
        EquipmentIdempotencyScope scope = EquipmentIdempotencyScope.from(command);
        String fingerprint = EquipmentFingerprint.sha256(command);
        ProcessedEquipmentCommand processed = repository.findProcessed(scope)
                .orElse(null);
        if (processed != null) {
            if (!processed.requestFingerprint().equals(fingerprint)) {
                throw new EquipmentIdempotencyConflictException();
            }
            return processed.result();
        }

        expeditionRepository.acquireLock(
                command.userId(),
                StarterExpeditionContent.EXPEDITION_ID
        );
        requireNoPendingResult(command.userId());
        EquipmentSlotDefinition slot = content.requireSlot(command.slotId());
        UniqueInventoryItemReference itemReference = null;
        InventoryItemDefinition itemDefinition = null;
        if (command.action() == EquipmentAction.EQUIP) {
            itemReference = repository.lockOwnedUniqueItem(
                            command.userId(),
                            command.itemInstanceId()
                    )
                    .orElseThrow(() -> new EquipmentItemUnavailableException(
                            command.itemInstanceId()
                    ));
            itemDefinition = content.requireEquippable(
                    slot.slotId(),
                    itemReference.itemId()
            );
        }
        Instant serverTime = Instant.now(clock).truncatedTo(ChronoUnit.MICROS);
        return repository.apply(
                scope,
                fingerprint,
                StarterEquipmentContent.CONTENT_VERSION,
                command.action(),
                slot,
                itemReference,
                itemDefinition,
                serverTime
        );
    }

    @Transactional(readOnly = true)
    public List<EquipmentSlotState> findSlots(String userId) {
        Map<String, EquipmentSlotState> states = new HashMap<>();
        repository.findAll(userId).forEach(state -> states.put(
                state.slotId(),
                state
        ));
        return content.slots().stream()
                .map(slot -> states.getOrDefault(
                        slot.slotId(),
                        EquipmentSlotState.empty(slot.slotId())
                ))
                .toList();
    }

    @Transactional(readOnly = true)
    public boolean isEquipped(String userId, String slotId, String itemId) {
        content.requireSlot(slotId);
        return repository.isEquipped(userId, slotId, itemId);
    }

    private void requireNoPendingResult(String userId) {
        eventResolutionRepository.findPendingResult(
                        userId,
                        StarterExpeditionContent.EXPEDITION_ID
                )
                .map(ProcessedEventResolution::result)
                .ifPresent(result -> {
                    throw new PendingEventResultException(
                            result.receiptId(),
                            result.eventId()
                    );
                });
    }
}
