package com.walkingrpg.backend.equipment.application;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.UUID;

import com.walkingrpg.backend.equipment.domain.EquipmentAction;
import com.walkingrpg.backend.equipment.domain.EquipmentCommand;
import com.walkingrpg.backend.equipment.domain.EquipmentResult;
import com.walkingrpg.backend.equipment.infrastructure.InMemoryEquipmentRepository;
import com.walkingrpg.backend.expedition.application.PendingEventResultException;
import com.walkingrpg.backend.expedition.application.StarterExpeditionContent;
import com.walkingrpg.backend.expedition.domain.EventIdempotencyScope;
import com.walkingrpg.backend.expedition.domain.EventPetRewardResult;
import com.walkingrpg.backend.expedition.domain.EventPilotRewardResult;
import com.walkingrpg.backend.expedition.domain.EventResolutionResult;
import com.walkingrpg.backend.expedition.domain.EventResolutionStatus;
import com.walkingrpg.backend.expedition.domain.ExpeditionProgressStatus;
import com.walkingrpg.backend.expedition.domain.ProcessedEventResolution;
import com.walkingrpg.backend.expedition.infrastructure.InMemoryEventResolutionRepository;
import com.walkingrpg.backend.expedition.infrastructure.InMemoryExpeditionRepository;
import com.walkingrpg.backend.inventory.application.StarterInventoryContent;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class EquipmentServiceTest {

    private static final Instant NOW = Instant.parse("2026-08-01T12:00:00Z");
    private static final UUID ITEM_INSTANCE_ID = UUID.fromString(
            "11111111-2222-3333-4444-555555555555"
    );

    private final InMemoryEquipmentRepository repository =
            new InMemoryEquipmentRepository();
    private final InMemoryExpeditionRepository expeditionRepository =
            new InMemoryExpeditionRepository();
    private final InMemoryEventResolutionRepository eventRepository =
            new InMemoryEventResolutionRepository();
    private final EquipmentService service = new EquipmentService(
            repository,
            new StarterEquipmentContent(),
            expeditionRepository,
            eventRepository,
            Clock.fixed(NOW, ZoneOffset.UTC)
    );

    @Test
    void shouldEquipReplayAndUnequipWithoutVersionInflation() {
        repository.putUniqueItem(
                "user-1",
                ITEM_INSTANCE_ID,
                StarterInventoryContent.RESONANCE_COMPASS_ID
        );
        EquipmentCommand equip = command(
                EquipmentAction.EQUIP,
                ITEM_INSTANCE_ID,
                "equipment-1"
        );

        EquipmentResult equipped = service.change(equip);
        EquipmentResult replayed = service.change(equip);
        EquipmentResult sameDesiredState = service.change(command(
                EquipmentAction.EQUIP,
                ITEM_INSTANCE_ID,
                "equipment-2"
        ));
        EquipmentResult unequipped = service.change(command(
                EquipmentAction.UNEQUIP,
                null,
                "equipment-3"
        ));

        assertSame(equipped, replayed);
        assertTrue(equipped.changed());
        assertEquals(1, equipped.version());
        assertFalse(sameDesiredState.changed());
        assertEquals(1, sameDesiredState.version());
        assertTrue(unequipped.changed());
        assertEquals(2, unequipped.version());
        assertFalse(repository.isEquipped(
                "user-1",
                StarterEquipmentContent.NAVIGATION_SLOT_ID,
                StarterInventoryContent.RESONANCE_COMPASS_ID
        ));
    }

    @Test
    void shouldRejectForeignItemAndConflictingKey() {
        repository.putUniqueItem(
                "user-1",
                ITEM_INSTANCE_ID,
                StarterInventoryContent.RESONANCE_COMPASS_ID
        );
        EquipmentCommand equip = command(
                EquipmentAction.EQUIP,
                ITEM_INSTANCE_ID,
                "same-key"
        );
        service.change(equip);

        assertThrows(
                EquipmentIdempotencyConflictException.class,
                () -> service.change(command(
                        EquipmentAction.UNEQUIP,
                        null,
                        "same-key"
                ))
        );
        assertThrows(
                EquipmentItemUnavailableException.class,
                () -> service.change(command(
                        EquipmentAction.EQUIP,
                        UUID.fromString(
                                "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
                        ),
                        "foreign-item"
                ))
        );
    }

    @Test
    void shouldReplayExactlyButBlockNewMutationWhileResultIsPending() {
        repository.putUniqueItem(
                "user-1",
                ITEM_INSTANCE_ID,
                StarterInventoryContent.RESONANCE_COMPASS_ID
        );
        EquipmentCommand equip = command(
                EquipmentAction.EQUIP,
                ITEM_INSTANCE_ID,
                "before-pending"
        );
        EquipmentResult first = service.change(equip);
        eventRepository.saveProcessed(
                new EventIdempotencyScope(
                        "user-1",
                        StarterExpeditionContent.FIRST_EVENT_ID,
                        "pending"
                ),
                pendingResult()
        );

        assertSame(first, service.change(equip));
        assertThrows(
                PendingEventResultException.class,
                () -> service.change(command(
                        EquipmentAction.UNEQUIP,
                        null,
                        "after-pending"
                ))
        );
        assertTrue(repository.isEquipped(
                "user-1",
                StarterEquipmentContent.NAVIGATION_SLOT_ID,
                StarterInventoryContent.RESONANCE_COMPASS_ID
        ));
    }

    private EquipmentCommand command(
            EquipmentAction action,
            UUID itemInstanceId,
            String key
    ) {
        return new EquipmentCommand(
                "user-1",
                StarterEquipmentContent.NAVIGATION_SLOT_ID,
                action,
                itemInstanceId,
                key
        );
    }

    private ProcessedEventResolution pendingResult() {
        return new ProcessedEventResolution(
                "a".repeat(64),
                new EventResolutionResult(
                        UUID.fromString(
                                "99999999-2222-3333-4444-555555555555"
                        ),
                        StarterExpeditionContent.CONTENT_VERSION,
                        StarterExpeditionContent.EXPEDITION_ID,
                        ExpeditionProgressStatus.IN_PROGRESS,
                        2,
                        StarterExpeditionContent.FIRST_EVENT_ID,
                        "Источник сигнала",
                        EventResolutionStatus.RESOLVED,
                        "analyze-signal",
                        "Проанализировать сигнал",
                        "Карта импульсов",
                        "Маршрут открыт.",
                        new EventPilotRewardResult(
                                "navigator-v1",
                                "Навигатор",
                                1,
                                10,
                                10,
                                100,
                                1
                        ),
                        new EventPetRewardResult(
                                "spark-v1",
                                "Искра",
                                1,
                                5,
                                5,
                                1
                        ),
                        null,
                        true,
                        null,
                        NOW.minusSeconds(1)
                )
        );
    }
}
