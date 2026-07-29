package com.walkingrpg.backend.expedition.application;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;

import com.walkingrpg.backend.expedition.domain.EventResolutionCommand;
import com.walkingrpg.backend.expedition.domain.EventResolutionResult;
import com.walkingrpg.backend.expedition.domain.ExpeditionProgressState;
import com.walkingrpg.backend.expedition.domain.ExpeditionProgressStatus;
import com.walkingrpg.backend.expedition.infrastructure.InMemoryEventResolutionRepository;
import com.walkingrpg.backend.expedition.infrastructure.InMemoryExpeditionRepository;
import com.walkingrpg.backend.inventory.application.InventoryService;
import com.walkingrpg.backend.inventory.infrastructure.InMemoryInventoryRepository;
import com.walkingrpg.backend.progression.application.ProgressionService;
import com.walkingrpg.backend.progression.application.StarterProgressionContent;
import com.walkingrpg.backend.progression.infrastructure.InMemoryProgressionRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class EventResolutionServiceTest {

    private static final Instant NOW = Instant.parse("2026-07-26T06:00:00Z");

    private InMemoryExpeditionRepository expeditionRepository;
    private InMemoryEventResolutionRepository eventResolutionRepository;
    private InMemoryInventoryRepository inventoryRepository;
    private StarterExpeditionContent content;
    private EventResolutionService service;

    @BeforeEach
    void setUp() {
        expeditionRepository = new InMemoryExpeditionRepository();
        eventResolutionRepository = new InMemoryEventResolutionRepository();
        inventoryRepository = new InMemoryInventoryRepository();
        content = new StarterExpeditionContent();
        expeditionRepository.saveState(
                "user-1",
                StarterExpeditionContent.EXPEDITION_ID,
                firstReadyState(),
                NOW
        );
        service = new EventResolutionService(
                expeditionRepository,
                eventResolutionRepository,
                new ProgressionService(
                        new InMemoryProgressionRepository(),
                        new StarterProgressionContent()
                ),
                new InventoryService(inventoryRepository),
                content,
                Clock.fixed(NOW, ZoneOffset.UTC)
        );
    }

    @Test
    void shouldResolveFirstEventAndContinueToSecondNode() {
        EventResolutionCommand command = command(
                StarterExpeditionContent.FIRST_EVENT_ID,
                "analyze-signal",
                "resolve-1"
        );

        EventResolutionResult first = service.resolve(command);
        EventResolutionResult replayed = service.resolve(command, false);
        ExpeditionProgressState state = expeditionRepository.findState(
                "user-1",
                StarterExpeditionContent.EXPEDITION_ID
        ).orElseThrow();

        assertSame(first, replayed);
        assertNotNull(first.receiptId());
        assertEquals(true, first.handoffRequired());
        assertEquals(
                first.receiptId(),
                eventResolutionRepository.findPendingResult(
                        "user-1",
                        StarterExpeditionContent.EXPEDITION_ID
                ).orElseThrow().result().receiptId()
        );
        assertEquals(ExpeditionProgressStatus.IN_PROGRESS, first.expeditionStatus());
        assertEquals(2, first.expeditionVersion());
        assertEquals(40, first.pilot().experienceGained());
        assertEquals(60, first.pilot().currentExperience());
        assertEquals(5, first.pet().bondGained());
        assertEquals(15, first.pet().bond());
        assertEquals("Карта импульсов", first.outcomeTitle());
        assertNull(first.material());
        assertEquals(StarterExpeditionContent.SECOND_NODE_ID,
                first.nextNode().nodeId());
        assertEquals(StarterExpeditionContent.SECOND_NODE_ID, state.currentNodeId());
        assertEquals(45, state.requiredEnergy());
        assertEquals(0, state.progressEnergy());
    }

    @Test
    void shouldKeepLegacyDeliveryOnCapableExactReplay() {
        EventResolutionCommand command = command(
                StarterExpeditionContent.FIRST_EVENT_ID,
                "analyze-signal",
                "legacy-delivery"
        );

        EventResolutionResult delivered = service.resolve(command, false);
        EventResolutionResult replayed = service.resolve(command, true);

        assertSame(delivered, replayed);
        assertEquals(false, delivered.handoffRequired());
        assertTrue(
                eventResolutionRepository.findPendingResult(
                        "user-1",
                        StarterExpeditionContent.EXPEDITION_ID
                ).isEmpty()
        );
    }

    @Test
    void shouldResolveSecondEventPersistMaterialAndContinueToThirdNode() {
        EventResolutionResult firstEvent = service.resolve(command(
                StarterExpeditionContent.FIRST_EVENT_ID,
                "analyze-signal",
                "first-event"
        ));
        eventResolutionRepository.acknowledgeResult(
                "user-1",
                firstEvent.receiptId(),
                NOW
        );
        expeditionRepository.saveState(
                "user-1",
                StarterExpeditionContent.EXPEDITION_ID,
                secondReadyState(3),
                NOW
        );
        EventResolutionCommand command = command(
                StarterExpeditionContent.SECOND_EVENT_ID,
                "stabilize-core",
                "second-event"
        );

        EventResolutionResult first = service.resolve(command);
        EventResolutionResult replayed = service.resolve(command);
        ExpeditionProgressState state = expeditionRepository.findState(
                "user-1",
                StarterExpeditionContent.EXPEDITION_ID
        ).orElseThrow();

        assertSame(first, replayed);
        assertNotNull(first.receiptId());
        assertEquals(ExpeditionProgressStatus.IN_PROGRESS, first.expeditionStatus());
        assertEquals(4, first.expeditionVersion());
        assertEquals(30, first.pilot().experienceGained());
        assertEquals(90, first.pilot().currentExperience());
        assertEquals(8, first.pet().bondGained());
        assertEquals(23, first.pet().bond());
        assertEquals("lumen-shard", first.material().itemId());
        assertEquals(2, first.material().quantityGained());
        assertEquals(2, first.material().quantityAfter());
        assertEquals(1, first.material().version());
        assertEquals(StarterExpeditionContent.THIRD_NODE_ID,
                first.nextNode().nodeId());
        assertEquals(1, inventoryRepository.findAll("user-1").size());
        assertEquals(2, inventoryRepository.findAll("user-1").getFirst().quantity());
        assertEquals(StarterExpeditionContent.THIRD_NODE_ID, state.currentNodeId());
        assertEquals(55, state.requiredEnergy());
        assertEquals(0, state.progressEnergy());
    }

    @Test
    void shouldCompleteChapterWithReceiptAndNoNextNode() {
        var finalNode = content.requireNode(
                StarterExpeditionContent.FINAL_NODE_ID
        );
        expeditionRepository.saveState(
                "user-1",
                StarterExpeditionContent.EXPEDITION_ID,
                new ExpeditionProgressState(
                        finalNode.requiredEnergy(),
                        finalNode.requiredEnergy(),
                        ExpeditionProgressStatus.EVENT_READY,
                        finalNode.currentNodeId(),
                        finalNode.event().eventId(),
                        35
                ),
                NOW
        );
        String choiceId = content.eventChoices(finalNode.event().eventId())
                .getFirst()
                .choiceId();

        EventResolutionResult result = service.resolve(command(
                finalNode.event().eventId(),
                choiceId,
                "resolve-final"
        ));

        assertEquals(ExpeditionProgressStatus.COMPLETED, result.expeditionStatus());
        assertNotNull(result.receiptId());
        assertNull(result.nextNode());
        assertEquals(
                ExpeditionProgressStatus.COMPLETED,
                expeditionRepository.findState(
                        "user-1",
                        StarterExpeditionContent.EXPEDITION_ID
                ).orElseThrow().status()
        );
    }

    @Test
    void shouldRejectAnotherResolutionUntilPendingReceiptIsAcknowledged() {
        EventResolutionResult first = service.resolve(command(
                StarterExpeditionContent.FIRST_EVENT_ID,
                "analyze-signal",
                "pending-first"
        ));
        expeditionRepository.saveState(
                "user-1",
                StarterExpeditionContent.EXPEDITION_ID,
                secondReadyState(3),
                NOW
        );

        PendingEventResultException conflict = assertThrows(
                PendingEventResultException.class,
                () -> service.resolve(command(
                        StarterExpeditionContent.SECOND_EVENT_ID,
                        "stabilize-core",
                        "pending-second"
                ))
        );
        assertEquals(first.receiptId(), conflict.receiptId());

        eventResolutionRepository.acknowledgeResult(
                "user-1",
                first.receiptId(),
                NOW
        );
        EventResolutionResult second = service.resolve(command(
                StarterExpeditionContent.SECOND_EVENT_ID,
                "stabilize-core",
                "pending-second"
        ));
        assertEquals(StarterExpeditionContent.SECOND_EVENT_ID, second.eventId());
    }

    @Test
    void shouldUseDifferentMaterialForFollowEchoChoice() {
        expeditionRepository.saveState(
                "user-1",
                StarterExpeditionContent.EXPEDITION_ID,
                secondReadyState(3),
                NOW
        );

        EventResolutionResult result = service.resolve(command(
                StarterExpeditionContent.SECOND_EVENT_ID,
                "follow-echo",
                "follow-echo-key"
        ));

        assertEquals("echo-thread", result.material().itemId());
        assertEquals(1, result.material().quantityGained());
        assertEquals(20, result.pilot().experienceGained());
        assertEquals(18, result.pet().bondGained());
    }

    @Test
    void shouldRejectReusedKeyWithDifferentChoice() {
        service.resolve(command(
                StarterExpeditionContent.FIRST_EVENT_ID,
                "analyze-signal",
                "same-key"
        ));

        assertThrows(
                EventResolutionIdempotencyConflictException.class,
                () -> service.resolve(command(
                        StarterExpeditionContent.FIRST_EVENT_ID,
                        "trust-spark",
                        "same-key"
                ))
        );
    }

    @Test
    void shouldRejectSecondResolutionWithAnotherKey() {
        EventResolutionResult first = service.resolve(command(
                StarterExpeditionContent.FIRST_EVENT_ID,
                "analyze-signal",
                "first-key"
        ));
        eventResolutionRepository.acknowledgeResult(
                "user-1",
                first.receiptId(),
                NOW
        );

        EventStateConflictException exception = assertThrows(
                EventStateConflictException.class,
                () -> service.resolve(command(
                        StarterExpeditionContent.FIRST_EVENT_ID,
                        "analyze-signal",
                        "second-key"
                ))
        );
        assertEquals("IN_PROGRESS", exception.status());
    }

    @Test
    void shouldRejectUnknownChoice() {
        assertThrows(
                EventResolutionValidationException.class,
                () -> service.resolve(command(
                        StarterExpeditionContent.FIRST_EVENT_ID,
                        "unknown-choice",
                        "unknown-key"
                ))
        );
    }

    private EventResolutionCommand command(
            String eventId,
            String choiceId,
            String key
    ) {
        return new EventResolutionCommand("user-1", eventId, choiceId, key);
    }

    private ExpeditionProgressState firstReadyState() {
        return new ExpeditionProgressState(
                30,
                30,
                ExpeditionProgressStatus.EVENT_READY,
                StarterExpeditionContent.FIRST_NODE_ID,
                StarterExpeditionContent.FIRST_EVENT_ID,
                1
        );
    }

    private ExpeditionProgressState secondReadyState(long version) {
        return new ExpeditionProgressState(
                45,
                45,
                ExpeditionProgressStatus.EVENT_READY,
                StarterExpeditionContent.SECOND_NODE_ID,
                StarterExpeditionContent.SECOND_EVENT_ID,
                version
        );
    }
}
