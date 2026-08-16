package com.walkingrpg.backend.itemupgrade.application;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import com.walkingrpg.backend.crafting.domain.CraftingIngredientResult;
import com.walkingrpg.backend.expedition.application.PendingEventResultException;
import com.walkingrpg.backend.expedition.application.StarterExpeditionContent;
import com.walkingrpg.backend.expedition.domain.EventNextNodeResult;
import com.walkingrpg.backend.expedition.domain.EventPetRewardResult;
import com.walkingrpg.backend.expedition.domain.EventPilotRewardResult;
import com.walkingrpg.backend.expedition.domain.EventResolutionResult;
import com.walkingrpg.backend.expedition.domain.EventResolutionStatus;
import com.walkingrpg.backend.expedition.domain.ExpeditionProgressStatus;
import com.walkingrpg.backend.expedition.domain.ProcessedEventResolution;
import com.walkingrpg.backend.expedition.infrastructure.EventResolutionRepository;
import com.walkingrpg.backend.expedition.infrastructure.ExpeditionRepository;
import com.walkingrpg.backend.inventory.domain.UniqueItemRarity;
import com.walkingrpg.backend.itemupgrade.domain.ItemUpgradeCommand;
import com.walkingrpg.backend.itemupgrade.domain.ItemUpgradeFingerprint;
import com.walkingrpg.backend.itemupgrade.domain.ItemUpgradeResult;
import com.walkingrpg.backend.itemupgrade.domain.ProcessedItemUpgradeCommand;
import com.walkingrpg.backend.itemupgrade.domain.UpgradedUniqueItemResult;
import com.walkingrpg.backend.itemupgrade.infrastructure.ItemUpgradeRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class ItemUpgradeServiceTest {

    private static final Instant NOW = Instant.parse("2026-08-15T08:00:00Z");
    private static final ItemUpgradeCommand COMMAND = new ItemUpgradeCommand(
            "user-1",
            StarterItemUpgradeContent.PRISM_SEXTANT_CALIBRATION_ID,
            "upgrade-1"
    );

    private final ItemUpgradeRepository repository =
            mock(ItemUpgradeRepository.class);
    private final ExpeditionRepository expeditionRepository =
            mock(ExpeditionRepository.class);
    private final EventResolutionRepository eventRepository =
            mock(EventResolutionRepository.class);
    private final StarterItemUpgradeContent content =
            new StarterItemUpgradeContent();

    @BeforeEach
    void setUp() {
        when(eventRepository.findPendingResult(anyString(), anyString()))
                .thenReturn(Optional.empty());
    }

    @Test
    void shouldApplyActiveUpgradeAndReturnAuthoritativeResult() {
        ItemUpgradeResult expected = result();
        when(repository.findProcessed(any())).thenReturn(Optional.empty());
        when(repository.upgrade(any(), anyString(), any(), any()))
                .thenReturn(expected);
        ItemUpgradeService service = service(
                StarterExpeditionContent.PRISM_SEXTANT_CONTENT_VERSION
        );

        ItemUpgradeResult actual = service.upgrade(COMMAND);

        assertEquals(expected, actual);
        verify(repository).acquireLock("user-1");
        verify(expeditionRepository).acquireLock(
                "user-1",
                StarterExpeditionContent.EXPEDITION_ID
        );
    }

    @Test
    void shouldReplayBeforeContentAndPendingEventChecks() {
        ItemUpgradeResult expected = result();
        when(repository.findProcessed(any())).thenReturn(Optional.of(
                new ProcessedItemUpgradeCommand(
                        ItemUpgradeFingerprint.sha256(COMMAND),
                        expected
                )
        ));
        ItemUpgradeService service = service(
                StarterExpeditionContent.VOID_ORCHARD_CONTENT_VERSION
        );

        assertEquals(expected, service.upgrade(COMMAND));
        verify(expeditionRepository, never()).acquireLock(anyString(), anyString());
        verify(repository, never()).upgrade(any(), anyString(), any(), any());
    }

    @Test
    void shouldHideUpgradeBeforeChapterV5Activation() {
        when(repository.findProcessed(any())).thenReturn(Optional.empty());
        ItemUpgradeService service = service(
                StarterExpeditionContent.VOID_ORCHARD_CONTENT_VERSION
        );

        assertThrows(
                ItemUpgradeNotFoundException.class,
                () -> service.upgrade(COMMAND)
        );
        verify(repository, never()).upgrade(any(), anyString(), any(), any());
    }

    @Test
    void shouldBlockNewUpgradeWhileEventResultIsPending() {
        when(repository.findProcessed(any())).thenReturn(Optional.empty());
        ProcessedEventResolution pending = pendingEventResult();
        when(eventRepository.findPendingResult(
                "user-1",
                StarterExpeditionContent.EXPEDITION_ID
        )).thenReturn(Optional.of(pending));
        ItemUpgradeService service = service(
                StarterExpeditionContent.PRISM_SEXTANT_CONTENT_VERSION
        );

        PendingEventResultException error = assertThrows(
                PendingEventResultException.class,
                () -> service.upgrade(COMMAND)
        );

        assertEquals(pending.result().receiptId(), error.receiptId());
        verify(repository, never()).upgrade(any(), anyString(), any(), any());
    }

    @Test
    void shouldExposeValidatedUpgradeSequenceByChapterVersion() {
        assertEquals(0, content.upgrades(
                StarterExpeditionContent.VOID_ORCHARD_CONTENT_VERSION
        ).size());
        assertEquals(1, content.upgrades(
                StarterExpeditionContent.PRISM_SEXTANT_CONTENT_VERSION
        ).size());
        assertEquals(1, content.upgrades(
                StarterExpeditionContent.CALIBRATED_SEXTANT_CONTENT_VERSION
        ).size());
        assertEquals(1, content.upgrades(
                StarterExpeditionContent.SECOND_DAWN_CONTENT_VERSION
        ).size());
        assertEquals(2, content.upgrades(
                StarterExpeditionContent
                        .SECOND_DAWN_ATTUNEMENT_CONTENT_VERSION
        ).size());
        var definition = content.require(
                StarterItemUpgradeContent.PRISM_SEXTANT_CALIBRATION_ID,
                StarterExpeditionContent.PRISM_SEXTANT_CONTENT_VERSION
        );
        assertEquals(1, definition.requiredLevel());
        assertEquals(2, definition.resultingLevel());
        assertEquals(UniqueItemRarity.UNCOMMON, definition.initialRarity());
        assertEquals(UniqueItemRarity.RARE, definition.resultingRarity());
        assertEquals(3, definition.ingredients().size());

        var attunement = content.require(
                StarterItemUpgradeContent
                        .PRISM_SEXTANT_SECOND_DAWN_ATTUNEMENT_ID,
                StarterExpeditionContent
                        .SECOND_DAWN_ATTUNEMENT_CONTENT_VERSION
        );
        assertEquals(
                StarterItemUpgradeContent.SECOND_DAWN_CONTENT_VERSION,
                attunement.contentVersion()
        );
        assertEquals(2, attunement.requiredLevel());
        assertEquals(3, attunement.resultingLevel());
        assertEquals(UniqueItemRarity.RARE, attunement.initialRarity());
        assertEquals(UniqueItemRarity.EPIC, attunement.resultingRarity());
        assertEquals(
                List.of(
                        "echo-thread:2",
                        "ion-bloom:2",
                        "dawn-fragment:2"
                ),
                attunement.ingredients().stream()
                        .map(ingredient -> ingredient.item().itemId()
                                + ":" + ingredient.quantity())
                        .toList()
        );
    }

    @Test
    void shouldHideSecondDawnAttunementBeforeChapterV8Activation() {
        assertThrows(
                ItemUpgradeNotFoundException.class,
                () -> content.require(
                        StarterItemUpgradeContent
                                .PRISM_SEXTANT_SECOND_DAWN_ATTUNEMENT_ID,
                        StarterExpeditionContent.SECOND_DAWN_CONTENT_VERSION
                )
        );
    }

    private ItemUpgradeService service(String activeContentVersion) {
        return new ItemUpgradeService(
                repository,
                content,
                expeditionRepository,
                eventRepository,
                () -> activeContentVersion,
                Clock.fixed(NOW, ZoneOffset.UTC)
        );
    }

    private ItemUpgradeResult result() {
        return new ItemUpgradeResult(
                StarterItemUpgradeContent.CONTENT_VERSION,
                StarterItemUpgradeContent.PRISM_SEXTANT_CALIBRATION_ID,
                "1",
                "Откалибровать призматический секстант",
                List.of(
                        new CraftingIngredientResult(
                                "echo-thread", "Нить эха", 2, 0, 2
                        ),
                        new CraftingIngredientResult(
                                "ion-bloom", "Ионный цветок", 1, 0, 2
                        ),
                        new CraftingIngredientResult(
                                "prism-dust", "Призматическая пыль", 1, 0, 2
                        )
                ),
                new UpgradedUniqueItemResult(
                        UUID.fromString(
                                "11111111-2222-3333-4444-555555555555"
                        ),
                        "prism-sextant",
                        "Призматический секстант",
                        "Прибор для чтения преломлённых маршрутов.",
                        1,
                        2,
                        UniqueItemRarity.RARE,
                        NOW
                ),
                NOW
        );
    }

    private ProcessedEventResolution pendingEventResult() {
        return new ProcessedEventResolution(
                "a".repeat(64),
                new EventResolutionResult(
                        UUID.fromString(
                                "10000000-0000-0000-0000-000000000001"
                        ),
                        StarterExpeditionContent.CONTENT_VERSION,
                        StarterExpeditionContent.EXPEDITION_ID,
                        ExpeditionProgressStatus.IN_PROGRESS,
                        2,
                        StarterExpeditionContent.FIRST_EVENT_ID,
                        "Источник сигнала",
                        EventResolutionStatus.RESOLVED,
                        "stabilize-signal",
                        "Стабилизировать сигнал",
                        "Сигнал стабилен",
                        "Маршрут открыт.",
                        new EventPilotRewardResult(
                                "navigator-v1", "Навигатор", 1,
                                10, 10, 100, 1
                        ),
                        new EventPetRewardResult(
                                "spark-v1", "Искра", 1, 5, 5, 1
                        ),
                        null,
                        true,
                        new EventNextNodeResult(
                                StarterExpeditionContent.SECOND_NODE_ID,
                                "Люминовые ворота"
                        ),
                        NOW.minusSeconds(1)
                )
        );
    }
}
