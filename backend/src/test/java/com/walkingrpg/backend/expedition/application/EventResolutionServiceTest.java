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
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertThrows;

class EventResolutionServiceTest {

    private static final Instant NOW = Instant.parse("2026-07-26T06:00:00Z");

    private InMemoryExpeditionRepository expeditionRepository;
    private InMemoryInventoryRepository inventoryRepository;
    private EventResolutionService service;

    @BeforeEach
    void setUp() {
        expeditionRepository = new InMemoryExpeditionRepository();
        inventoryRepository = new InMemoryInventoryRepository();
        expeditionRepository.saveState(
                "user-1",
                StarterExpeditionContent.EXPEDITION_ID,
                firstReadyState(),
                NOW
        );
        service = new EventResolutionService(
                expeditionRepository,
                new InMemoryEventResolutionRepository(),
                new ProgressionService(
                        new InMemoryProgressionRepository(),
                        new StarterProgressionContent()
                ),
                new InventoryService(inventoryRepository),
                new StarterExpeditionContent(),
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
        EventResolutionResult replayed = service.resolve(command);
        ExpeditionProgressState state = expeditionRepository.findState(
                "user-1",
                StarterExpeditionContent.EXPEDITION_ID
        ).orElseThrow();

        assertSame(first, replayed);
        assertEquals(ExpeditionProgressStatus.IN_PROGRESS, first.expeditionStatus());
        assertEquals(2, first.expeditionVersion());
        assertEquals(40, first.pilot().experienceGained());
        assertEquals(60, first.pilot().currentExperience());
        assertEquals(5, first.pet().bondGained());
        assertEquals(15, first.pet().bond());
        assertEquals("Карта импульсов", first.outcomeTitle());
        assertNull(first.material());
        assertEquals(StarterExpeditionContent.SECOND_NODE_ID, state.currentNodeId());
        assertEquals(45, state.requiredEnergy());
        assertEquals(0, state.progressEnergy());
    }

    @Test
    void shouldResolveSecondEventPersistMaterialAndContinueToThirdNode() {
        service.resolve(command(
                StarterExpeditionContent.FIRST_EVENT_ID,
                "analyze-signal",
                "first-event"
        ));
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
        assertEquals(1, inventoryRepository.findAll("user-1").size());
        assertEquals(2, inventoryRepository.findAll("user-1").getFirst().quantity());
        assertEquals(StarterExpeditionContent.THIRD_NODE_ID, state.currentNodeId());
        assertEquals(55, state.requiredEnergy());
        assertEquals(0, state.progressEnergy());
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
        service.resolve(command(
                StarterExpeditionContent.FIRST_EVENT_ID,
                "analyze-signal",
                "first-key"
        ));

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
