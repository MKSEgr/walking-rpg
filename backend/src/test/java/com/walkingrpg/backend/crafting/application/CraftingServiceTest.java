package com.walkingrpg.backend.crafting.application;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.UUID;

import com.walkingrpg.backend.crafting.domain.CraftingCommand;
import com.walkingrpg.backend.crafting.domain.CraftingResult;
import com.walkingrpg.backend.crafting.infrastructure.InMemoryCraftingRepository;
import com.walkingrpg.backend.expedition.application.PendingEventResultException;
import com.walkingrpg.backend.expedition.application.StarterExpeditionContent;
import com.walkingrpg.backend.expedition.domain.EventIdempotencyScope;
import com.walkingrpg.backend.expedition.domain.EventNextNodeResult;
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
import static org.junit.jupiter.api.Assertions.assertThrows;

class CraftingServiceTest {

    private static final Instant NOW = Instant.parse("2026-08-01T08:00:00Z");

    private final InMemoryCraftingRepository repository =
            new InMemoryCraftingRepository();
    private final InMemoryEventResolutionRepository eventRepository =
            new InMemoryEventResolutionRepository();
    private final CraftingService service = new CraftingService(
            repository,
            new StarterCraftingContent(),
            new InMemoryExpeditionRepository(),
            eventRepository,
            Clock.fixed(NOW, ZoneOffset.UTC)
    );

    @Test
    void shouldConsumeMaterialsCreateUniqueItemAndReplayExactly() {
        repository.putMaterial(
                "user-1",
                StarterInventoryContent.LUMEN_SHARD_ID,
                3,
                2
        );
        repository.putMaterial(
                "user-1",
                StarterInventoryContent.ECHO_THREAD_ID,
                2,
                1
        );
        CraftingCommand command = new CraftingCommand(
                "user-1",
                StarterCraftingContent.RESONANCE_COMPASS_RECIPE_ID,
                "craft-1"
        );

        CraftingResult created = service.craft(command);
        CraftingResult replayed = service.craft(command);

        assertEquals(created, replayed);
        assertEquals(StarterInventoryContent.RESONANCE_COMPASS_ID,
                created.craftedItem().itemId());
        assertEquals(2, created.consumedIngredients().size());
        assertEquals(1, repository.materialQuantity(
                "user-1",
                StarterInventoryContent.LUMEN_SHARD_ID
        ));
        assertEquals(1, repository.materialQuantity(
                "user-1",
                StarterInventoryContent.ECHO_THREAD_ID
        ));

        assertThrows(
                CraftingStateConflictException.class,
                () -> service.craft(new CraftingCommand(
                        "user-1",
                        StarterCraftingContent.RESONANCE_COMPASS_RECIPE_ID,
                        "craft-2"
                ))
        );
        assertEquals(1, repository.materialQuantity(
                "user-1",
                StarterInventoryContent.LUMEN_SHARD_ID
        ));
    }

    @Test
    void shouldReportEveryMissingIngredientWithoutMutation() {
        repository.putMaterial(
                "user-2",
                StarterInventoryContent.LUMEN_SHARD_ID,
                1,
                1
        );

        InsufficientCraftingMaterialsException error = assertThrows(
                InsufficientCraftingMaterialsException.class,
                () -> service.craft(new CraftingCommand(
                        "user-2",
                        StarterCraftingContent.RESONANCE_COMPASS_RECIPE_ID,
                        "craft-missing"
                ))
        );

        assertEquals(2, error.shortages().size());
        assertEquals(1, repository.materialQuantity(
                "user-2",
                StarterInventoryContent.LUMEN_SHARD_ID
        ));
    }

    @Test
    void shouldGatePrismSextantRecipeAndConsumeLateChapterMaterials() {
        StarterCraftingContent craftingContent = new StarterCraftingContent();
        assertEquals(1, craftingContent.recipes(
                StarterExpeditionContent.VOID_ORCHARD_CONTENT_VERSION
        ).size());
        assertEquals(2, craftingContent.recipes(
                StarterExpeditionContent.PRISM_SEXTANT_CONTENT_VERSION
        ).size());
        CraftingService stagedService = new CraftingService(
                repository,
                craftingContent,
                new InMemoryExpeditionRepository(),
                eventRepository,
                () -> StarterExpeditionContent.VOID_ORCHARD_CONTENT_VERSION,
                Clock.fixed(NOW, ZoneOffset.UTC)
        );
        CraftingCommand command = new CraftingCommand(
                "user-prism",
                StarterCraftingContent.PRISM_SEXTANT_RECIPE_ID,
                "craft-prism"
        );

        assertThrows(
                CraftingRecipeNotFoundException.class,
                () -> stagedService.craft(command)
        );

        repository.putMaterial(
                "user-prism",
                StarterInventoryContent.PRISM_DUST_ID,
                3,
                1
        );
        repository.putMaterial(
                "user-prism",
                StarterInventoryContent.ION_BLOOM_ID,
                1,
                1
        );
        repository.putMaterial(
                "user-prism",
                StarterInventoryContent.DAWN_FRAGMENT_ID,
                2,
                1
        );
        CraftingService activeService = new CraftingService(
                repository,
                new StarterCraftingContent(),
                new InMemoryExpeditionRepository(),
                eventRepository,
                () -> StarterExpeditionContent.PRISM_SEXTANT_CONTENT_VERSION,
                Clock.fixed(NOW, ZoneOffset.UTC)
        );

        CraftingResult result = activeService.craft(command);

        assertEquals(StarterCraftingContent.PRISM_CONTENT_VERSION,
                result.contentVersion());
        assertEquals(StarterInventoryContent.PRISM_SEXTANT_ID,
                result.craftedItem().itemId());
        assertEquals(3, result.consumedIngredients().size());
        assertEquals(1, repository.materialQuantity(
                "user-prism",
                StarterInventoryContent.PRISM_DUST_ID
        ));
        assertEquals(0, repository.materialQuantity(
                "user-prism",
                StarterInventoryContent.ION_BLOOM_ID
        ));
        assertEquals(1, repository.materialQuantity(
                "user-prism",
                StarterInventoryContent.DAWN_FRAGMENT_ID
        ));
    }

    @Test
    void shouldReplayExactlyButBlockNewCraftWhileEventResultIsPending() {
        String userId = "pending-result-user";
        repository.putMaterial(
                userId,
                StarterInventoryContent.LUMEN_SHARD_ID,
                3,
                2
        );
        repository.putMaterial(
                userId,
                StarterInventoryContent.ECHO_THREAD_ID,
                2,
                1
        );
        CraftingCommand original = new CraftingCommand(
                userId,
                StarterCraftingContent.RESONANCE_COMPASS_RECIPE_ID,
                "craft-before-pending"
        );
        CraftingResult created = service.craft(original);
        ProcessedEventResolution pending = pendingEventResult();
        eventRepository.saveProcessed(
                new EventIdempotencyScope(
                        userId,
                        pending.result().eventId(),
                        "pending-result"
                ),
                pending
        );

        assertEquals(created, service.craft(original));
        PendingEventResultException error = assertThrows(
                PendingEventResultException.class,
                () -> service.craft(new CraftingCommand(
                        userId,
                        StarterCraftingContent.RESONANCE_COMPASS_RECIPE_ID,
                        "new-craft-while-pending"
                ))
        );

        assertEquals(pending.result().receiptId(), error.receiptId());
        assertEquals(pending.result().eventId(), error.eventId());
        assertEquals(1, repository.materialQuantity(
                userId,
                StarterInventoryContent.LUMEN_SHARD_ID
        ));
        assertEquals(1, repository.materialQuantity(
                userId,
                StarterInventoryContent.ECHO_THREAD_ID
        ));
    }

    private ProcessedEventResolution pendingEventResult() {
        return new ProcessedEventResolution(
                "a".repeat(64),
                new EventResolutionResult(
                        UUID.fromString("10000000-0000-0000-0000-000000000001"),
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
                        new EventNextNodeResult(
                                StarterExpeditionContent.SECOND_NODE_ID,
                                "Люминовые ворота"
                        ),
                        NOW.minusSeconds(1)
                )
        );
    }
}
