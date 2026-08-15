package com.walkingrpg.backend.expedition.application;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicReference;

import com.walkingrpg.backend.equipment.application.EquipmentService;
import com.walkingrpg.backend.equipment.application.StarterEquipmentContent;
import com.walkingrpg.backend.equipment.domain.EquipmentAction;
import com.walkingrpg.backend.equipment.domain.EquipmentCommand;
import com.walkingrpg.backend.equipment.infrastructure.InMemoryEquipmentRepository;
import com.walkingrpg.backend.expedition.domain.EventResolutionCommand;
import com.walkingrpg.backend.expedition.domain.EventResolutionResult;
import com.walkingrpg.backend.expedition.domain.ExpeditionProgressState;
import com.walkingrpg.backend.expedition.domain.ExpeditionProgressStatus;
import com.walkingrpg.backend.expedition.infrastructure.InMemoryEventResolutionRepository;
import com.walkingrpg.backend.expedition.infrastructure.InMemoryExpeditionRepository;
import com.walkingrpg.backend.inventory.application.InventoryService;
import com.walkingrpg.backend.inventory.application.StarterInventoryContent;
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
    private InMemoryEquipmentRepository equipmentRepository;
    private EquipmentService equipmentService;
    private AtomicReference<String> activeContentVersion;
    private EventResolutionService service;

    @BeforeEach
    void setUp() {
        expeditionRepository = new InMemoryExpeditionRepository();
        eventResolutionRepository = new InMemoryEventResolutionRepository();
        inventoryRepository = new InMemoryInventoryRepository();
        content = new StarterExpeditionContent();
        equipmentRepository = new InMemoryEquipmentRepository();
        activeContentVersion = new AtomicReference<>(
                StarterExpeditionContent.STORM_RIFT_CONTENT_VERSION
        );
        equipmentService = new EquipmentService(
                equipmentRepository,
                new StarterEquipmentContent(),
                expeditionRepository,
                eventResolutionRepository,
                Clock.fixed(NOW, ZoneOffset.UTC)
        );
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
                equipmentService,
                activeContentVersion::get,
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

    @Test
    void shouldRequireEquippedCompassAndEnterOptionalResonanceRoute() {
        var mirrorNode = content.requireNode(
                StarterExpeditionContent.MIRROR_DELTA_NODE_ID
        );
        expeditionRepository.saveState(
                "user-1",
                StarterExpeditionContent.EXPEDITION_ID,
                readyState(mirrorNode, 20),
                NOW
        );

        assertThrows(
                EventChoiceUnavailableException.class,
                () -> service.resolve(command(
                        StarterExpeditionContent.MIRROR_DELTA_EVENT_ID,
                        StarterExpeditionContent.RESONANCE_ROUTE_CHOICE_ID,
                        "locked-route"
                ))
        );
        assertTrue(inventoryRepository.findAll("user-1").isEmpty());

        UUID itemInstanceId = UUID.fromString(
                "11111111-2222-3333-4444-555555555555"
        );
        equipmentRepository.putUniqueItem(
                "user-1",
                itemInstanceId,
                StarterInventoryContent.RESONANCE_COMPASS_ID
        );
        equipmentService.change(new EquipmentCommand(
                "user-1",
                StarterEquipmentContent.NAVIGATION_SLOT_ID,
                EquipmentAction.EQUIP,
                itemInstanceId,
                "equip-compass"
        ));

        EventResolutionResult result = service.resolve(command(
                StarterExpeditionContent.MIRROR_DELTA_EVENT_ID,
                StarterExpeditionContent.RESONANCE_ROUTE_CHOICE_ID,
                "open-route"
        ));

        assertEquals(
                StarterExpeditionContent.RESONANCE_ROUTE_NODE_ID,
                result.nextNode().nodeId()
        );
        assertEquals(StarterInventoryContent.DAWN_FRAGMENT_ID,
                result.material().itemId());
        assertEquals(
                StarterExpeditionContent.RESONANCE_ROUTE_NODE_ID,
                expeditionRepository.findState(
                        "user-1",
                        StarterExpeditionContent.EXPEDITION_ID
                ).orElseThrow().currentNodeId()
        );
    }

    @Test
    void shouldEnterStormRiftAndRejoinAtEmberStation() {
        var stormArchive = content.requireNode(
                StarterExpeditionContent.STORM_ARCHIVE_NODE_ID
        );
        expeditionRepository.saveState(
                "user-1",
                StarterExpeditionContent.EXPEDITION_ID,
                readyState(stormArchive, 24),
                NOW
        );

        assertThrows(
                EventChoiceUnavailableException.class,
                () -> service.resolve(command(
                        StarterExpeditionContent.STORM_ARCHIVE_EVENT_ID,
                        StarterExpeditionContent.STORM_RIFT_CHOICE_ID,
                        "locked-storm-rift"
                ))
        );

        UUID itemInstanceId = UUID.fromString(
                "12345678-90ab-cdef-1234-567890abcdef"
        );
        equipmentRepository.putUniqueItem(
                "user-1",
                itemInstanceId,
                StarterInventoryContent.RESONANCE_COMPASS_ID
        );
        equipmentService.change(new EquipmentCommand(
                "user-1",
                StarterEquipmentContent.NAVIGATION_SLOT_ID,
                EquipmentAction.EQUIP,
                itemInstanceId,
                "equip-storm-compass"
        ));

        EventResolutionResult entered = service.resolve(command(
                StarterExpeditionContent.STORM_ARCHIVE_EVENT_ID,
                StarterExpeditionContent.STORM_RIFT_CHOICE_ID,
                "enter-storm-rift"
        ));

        assertEquals(
                StarterExpeditionContent.STORM_RIFT_CONTENT_VERSION,
                entered.contentVersion()
        );
        assertEquals(
                StarterExpeditionContent.STORM_RIFT_NODE_ID,
                entered.nextNode().nodeId()
        );
        assertEquals(StarterInventoryContent.ION_BLOOM_ID,
                entered.material().itemId());
        eventResolutionRepository.acknowledgeResult(
                "user-1",
                entered.receiptId(),
                NOW
        );

        var stormRift = content.requireNode(
                StarterExpeditionContent.STORM_RIFT_NODE_ID
        );
        expeditionRepository.saveState(
                "user-1",
                StarterExpeditionContent.EXPEDITION_ID,
                readyState(stormRift, 26),
                NOW
        );
        EventResolutionResult returned = service.resolve(command(
                StarterExpeditionContent.STORM_RIFT_EVENT_ID,
                "decode-lightning-script",
                "leave-storm-rift"
        ));

        assertEquals(
                StarterExpeditionContent.EMBER_STATION_NODE_ID,
                returned.nextNode().nodeId()
        );
        assertEquals(StarterInventoryContent.ECHO_THREAD_ID,
                returned.material().itemId());
        assertEquals(2, returned.material().quantityGained());
    }

    @Test
    void shouldFollowRootMemoryBranchAndRejoinAtStarWell() {
        activeContentVersion.set(
                StarterExpeditionContent.VOID_ORCHARD_CONTENT_VERSION
        );
        var voidOrchard = content.requireNode(
                StarterExpeditionContent.VOID_ORCHARD_NODE_ID
        );
        expeditionRepository.saveState(
                "user-1",
                StarterExpeditionContent.EXPEDITION_ID,
                readyState(voidOrchard, 28),
                NOW
        );

        EventResolutionResult entered = service.resolve(command(
                StarterExpeditionContent.VOID_ORCHARD_EVENT_ID,
                StarterExpeditionContent.ROOT_ECHO_CHOICE_ID,
                "enter-root-memory"
        ));

        assertEquals(
                StarterExpeditionContent.VOID_ORCHARD_CONTENT_VERSION,
                entered.contentVersion()
        );
        assertEquals(
                StarterExpeditionContent.ROOT_MEMORY_NODE_ID,
                entered.nextNode().nodeId()
        );
        assertEquals(StarterInventoryContent.ECHO_THREAD_ID,
                entered.material().itemId());
        assertEquals(1, entered.material().quantityGained());
        assertEquals(36, entered.pilot().experienceGained());
        assertEquals(22, entered.pet().bondGained());
        eventResolutionRepository.acknowledgeResult(
                "user-1",
                entered.receiptId(),
                NOW
        );

        var rootMemory = content.requireNode(
                StarterExpeditionContent.ROOT_MEMORY_NODE_ID
        );
        expeditionRepository.saveState(
                "user-1",
                StarterExpeditionContent.EXPEDITION_ID,
                readyState(rootMemory, 30),
                NOW
        );
        EventResolutionResult returned = service.resolve(command(
                StarterExpeditionContent.ROOT_MEMORY_EVENT_ID,
                "map-root-memory",
                "leave-root-memory"
        ));

        assertEquals(
                StarterExpeditionContent.STAR_WELL_NODE_ID,
                returned.nextNode().nodeId()
        );
        assertEquals(StarterInventoryContent.ECHO_THREAD_ID,
                returned.material().itemId());
        assertEquals(2, returned.material().quantityGained());
        assertEquals(46, returned.pilot().experienceGained());
        assertEquals(15, returned.pet().bondGained());
    }

    @Test
    void shouldFollowLightCanopyBranchAndRejoinAtStarWell() {
        activeContentVersion.set(
                StarterExpeditionContent.VOID_ORCHARD_CONTENT_VERSION
        );
        var voidOrchard = content.requireNode(
                StarterExpeditionContent.VOID_ORCHARD_NODE_ID
        );
        expeditionRepository.saveState(
                "user-1",
                StarterExpeditionContent.EXPEDITION_ID,
                readyState(voidOrchard, 28),
                NOW
        );

        EventResolutionResult entered = service.resolve(command(
                StarterExpeditionContent.VOID_ORCHARD_EVENT_ID,
                StarterExpeditionContent.LIGHT_CANOPY_CHOICE_ID,
                "enter-light-canopy"
        ));

        assertEquals(
                StarterExpeditionContent.LIGHT_CANOPY_NODE_ID,
                entered.nextNode().nodeId()
        );
        assertEquals(StarterInventoryContent.ION_BLOOM_ID,
                entered.material().itemId());
        assertEquals(1, entered.material().quantityGained());
        assertEquals(44, entered.pilot().experienceGained());
        assertEquals(18, entered.pet().bondGained());
        eventResolutionRepository.acknowledgeResult(
                "user-1",
                entered.receiptId(),
                NOW
        );

        var lightCanopy = content.requireNode(
                StarterExpeditionContent.LIGHT_CANOPY_NODE_ID
        );
        expeditionRepository.saveState(
                "user-1",
                StarterExpeditionContent.EXPEDITION_ID,
                readyState(lightCanopy, 30),
                NOW
        );
        EventResolutionResult returned = service.resolve(command(
                StarterExpeditionContent.LIGHT_CANOPY_EVENT_ID,
                "leap-between-rays",
                "leave-light-canopy"
        ));

        assertEquals(
                StarterExpeditionContent.STAR_WELL_NODE_ID,
                returned.nextNode().nodeId()
        );
        assertEquals(StarterInventoryContent.DAWN_FRAGMENT_ID,
                returned.material().itemId());
        assertEquals(1, returned.material().quantityGained());
        assertEquals(31, returned.pilot().experienceGained());
        assertEquals(25, returned.pet().bondGained());
    }

    @Test
    void shouldRequirePrismSextantAndRejoinAfterSpectrumObservatory() {
        activeContentVersion.set(
                StarterExpeditionContent.PRISM_SEXTANT_CONTENT_VERSION
        );
        var starWell = content.requireNode(
                StarterExpeditionContent.STAR_WELL_NODE_ID
        );
        expeditionRepository.saveState(
                "user-1",
                StarterExpeditionContent.EXPEDITION_ID,
                readyState(starWell, 32),
                NOW
        );
        EventResolutionCommand enterCommand = command(
                StarterExpeditionContent.STAR_WELL_EVENT_ID,
                StarterExpeditionContent.PRISM_SEXTANT_ROUTE_CHOICE_ID,
                "enter-spectrum-observatory"
        );

        assertThrows(
                EventChoiceUnavailableException.class,
                () -> service.resolve(enterCommand)
        );

        UUID sextantInstanceId = UUID.fromString(
                "bbbbbbbb-cccc-dddd-eeee-ffffffffffff"
        );
        equipmentRepository.putUniqueItem(
                "user-1",
                sextantInstanceId,
                StarterInventoryContent.PRISM_SEXTANT_ID
        );
        equipmentService.change(new EquipmentCommand(
                "user-1",
                StarterEquipmentContent.NAVIGATION_SLOT_ID,
                EquipmentAction.EQUIP,
                sextantInstanceId,
                "equip-prism-sextant"
        ));

        EventResolutionResult entered = service.resolve(enterCommand);

        assertEquals(
                StarterExpeditionContent.PRISM_SEXTANT_CONTENT_VERSION,
                entered.contentVersion()
        );
        assertEquals(
                StarterExpeditionContent.SPECTRUM_OBSERVATORY_NODE_ID,
                entered.nextNode().nodeId()
        );
        assertEquals(StarterInventoryContent.PRISM_DUST_ID,
                entered.material().itemId());
        eventResolutionRepository.acknowledgeResult(
                "user-1",
                entered.receiptId(),
                NOW
        );

        var observatory = content.requireNode(
                StarterExpeditionContent.SPECTRUM_OBSERVATORY_NODE_ID
        );
        expeditionRepository.saveState(
                "user-1",
                StarterExpeditionContent.EXPEDITION_ID,
                readyState(observatory, 34),
                NOW
        );
        EventResolutionResult returned = service.resolve(command(
                StarterExpeditionContent.SPECTRUM_OBSERVATORY_EVENT_ID,
                "chase-dawn-refraction",
                "leave-spectrum-observatory"
        ));

        assertEquals(
                StarterExpeditionContent.HORIZON_SPIRE_NODE_ID,
                returned.nextNode().nodeId()
        );
        assertEquals(StarterInventoryContent.DAWN_FRAGMENT_ID,
                returned.material().itemId());
        assertEquals(2, returned.material().quantityGained());
    }

    @Test
    void shouldReplayVoidOrchardBranchAfterActivationFallsBack() {
        activeContentVersion.set(
                StarterExpeditionContent.VOID_ORCHARD_CONTENT_VERSION
        );
        var voidOrchard = content.requireNode(
                StarterExpeditionContent.VOID_ORCHARD_NODE_ID
        );
        expeditionRepository.saveState(
                "user-1",
                StarterExpeditionContent.EXPEDITION_ID,
                readyState(voidOrchard, 28),
                NOW
        );
        EventResolutionCommand command = command(
                StarterExpeditionContent.VOID_ORCHARD_EVENT_ID,
                StarterExpeditionContent.ROOT_ECHO_CHOICE_ID,
                "void-orchard-replay"
        );

        EventResolutionResult first = service.resolve(command);
        activeContentVersion.set(
                StarterExpeditionContent.STORM_RIFT_CONTENT_VERSION
        );
        EventResolutionResult replayed = service.resolve(command);

        assertSame(first, replayed);
        assertEquals(
                StarterExpeditionContent.VOID_ORCHARD_CONTENT_VERSION,
                replayed.contentVersion()
        );
        assertEquals(
                StarterExpeditionContent.ROOT_MEMORY_NODE_ID,
                replayed.nextNode().nodeId()
        );
    }

    @Test
    void shouldReplayRouteResultAfterClusterActivationChanges() {
        var mirrorNode = content.requireNode(
                StarterExpeditionContent.MIRROR_DELTA_NODE_ID
        );
        expeditionRepository.saveState(
                "user-1",
                StarterExpeditionContent.EXPEDITION_ID,
                readyState(mirrorNode, 20),
                NOW
        );
        UUID itemInstanceId = UUID.fromString(
                "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
        );
        equipmentRepository.putUniqueItem(
                "user-1",
                itemInstanceId,
                StarterInventoryContent.RESONANCE_COMPASS_ID
        );
        equipmentService.change(new EquipmentCommand(
                "user-1",
                StarterEquipmentContent.NAVIGATION_SLOT_ID,
                EquipmentAction.EQUIP,
                itemInstanceId,
                "equip-replay-compass"
        ));
        EventResolutionCommand command = command(
                StarterExpeditionContent.MIRROR_DELTA_EVENT_ID,
                StarterExpeditionContent.RESONANCE_ROUTE_CHOICE_ID,
                "activated-route-replay"
        );

        EventResolutionResult first = service.resolve(command);
        activeContentVersion.set(StarterExpeditionContent.LEGACY_CONTENT_VERSION);
        EventResolutionResult replayed = service.resolve(command);

        assertSame(first, replayed);
        assertEquals(
                StarterExpeditionContent.STORM_RIFT_CONTENT_VERSION,
                replayed.contentVersion()
        );
        assertEquals(
                StarterExpeditionContent.RESONANCE_ROUTE_NODE_ID,
                replayed.nextNode().nodeId()
        );
    }

    @Test
    void shouldKeepDefaultMirrorRouteAndReturnFromOptionalNodeToStormArchive() {
        var mirrorNode = content.requireNode(
                StarterExpeditionContent.MIRROR_DELTA_NODE_ID
        );
        expeditionRepository.saveState(
                "user-1",
                StarterExpeditionContent.EXPEDITION_ID,
                readyState(mirrorNode, 20),
                NOW
        );
        String ordinaryChoice = content.eventChoices(
                        StarterExpeditionContent.MIRROR_DELTA_EVENT_ID
                )
                .getFirst()
                .choiceId();

        EventResolutionResult ordinary = service.resolve(command(
                StarterExpeditionContent.MIRROR_DELTA_EVENT_ID,
                ordinaryChoice,
                "ordinary-route"
        ));
        assertEquals(
                StarterExpeditionContent.STORM_ARCHIVE_NODE_ID,
                ordinary.nextNode().nodeId()
        );
        eventResolutionRepository.acknowledgeResult(
                "user-1",
                ordinary.receiptId(),
                NOW
        );

        var resonanceNode = content.requireNode(
                StarterExpeditionContent.RESONANCE_ROUTE_NODE_ID
        );
        expeditionRepository.saveState(
                "user-1",
                StarterExpeditionContent.EXPEDITION_ID,
                readyState(resonanceNode, 22),
                NOW
        );
        EventResolutionResult branch = service.resolve(command(
                StarterExpeditionContent.RESONANCE_ROUTE_EVENT_ID,
                content.eventChoices(
                        StarterExpeditionContent.RESONANCE_ROUTE_EVENT_ID
                ).getFirst().choiceId(),
                "branch-return"
        ));
        assertEquals(
                StarterExpeditionContent.STORM_ARCHIVE_NODE_ID,
                branch.nextNode().nodeId()
        );
    }

    @Test
    void shouldTimestampResolutionAfterExpeditionLock() {
        MutableClock clock = new MutableClock(NOW.minusSeconds(30));
        InMemoryExpeditionRepository orderedRepository =
                new InMemoryExpeditionRepository() {
                    @Override
                    public void acquireLock(String userId, String expeditionId) {
                        clock.set(NOW);
                    }
                };
        orderedRepository.saveState(
                "user-1",
                StarterExpeditionContent.EXPEDITION_ID,
                firstReadyState(),
                NOW.minusSeconds(30)
        );
        EventResolutionService orderedService = new EventResolutionService(
                orderedRepository,
                new InMemoryEventResolutionRepository(),
                new ProgressionService(
                        new InMemoryProgressionRepository(),
                        new StarterProgressionContent()
                ),
                new InventoryService(new InMemoryInventoryRepository()),
                content,
                clock
        );

        EventResolutionResult result = orderedService.resolve(command(
                StarterExpeditionContent.FIRST_EVENT_ID,
                "analyze-signal",
                "resolution-lock-time"
        ));

        assertEquals(NOW, result.serverTime());
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

    private ExpeditionProgressState readyState(
            com.walkingrpg.backend.expedition.domain.ExpeditionDefinition node,
            long version
    ) {
        return new ExpeditionProgressState(
                node.requiredEnergy(),
                node.requiredEnergy(),
                ExpeditionProgressStatus.EVENT_READY,
                node.currentNodeId(),
                node.event().eventId(),
                version
        );
    }

    private static final class MutableClock extends Clock {
        private Instant current;
        private final ZoneId zone;

        private MutableClock(Instant current) {
            this(current, ZoneOffset.UTC);
        }

        private MutableClock(Instant current, ZoneId zone) {
            this.current = current;
            this.zone = zone;
        }

        @Override
        public ZoneId getZone() {
            return zone;
        }

        @Override
        public synchronized Clock withZone(ZoneId requestedZone) {
            return zone.equals(requestedZone)
                    ? this
                    : new MutableClock(current, requestedZone);
        }

        @Override
        public synchronized Instant instant() {
            return current;
        }

        private synchronized void set(Instant value) {
            current = value;
        }
    }
}
