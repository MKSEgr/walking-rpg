package com.walkingrpg.backend.inventory.application;

import java.time.Instant;

import com.walkingrpg.backend.inventory.domain.InventoryLedgerConflictException;
import com.walkingrpg.backend.inventory.domain.InventoryRewardDefinition;
import com.walkingrpg.backend.inventory.domain.InventoryRewardResult;
import com.walkingrpg.backend.inventory.infrastructure.InMemoryInventoryRepository;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class InventoryServiceTest {

    private static final Instant NOW = Instant.parse("2026-07-26T06:00:00Z");

    private final StarterInventoryContent content = new StarterInventoryContent();
    private final InventoryService service = new InventoryService(
            new InMemoryInventoryRepository()
    );

    @Test
    void shouldRewardMaterialAndReplaySameSource() {
        InventoryRewardDefinition reward = new InventoryRewardDefinition(
                content.require(StarterInventoryContent.LUMEN_SHARD_ID),
                2
        );

        InventoryRewardResult first = service.rewardEventMaterial(
                "user-1",
                reward,
                "echo-vault-v1:resolve-1",
                NOW
        );
        InventoryRewardResult replayed = service.rewardEventMaterial(
                "user-1",
                reward,
                "echo-vault-v1:resolve-1",
                NOW.plusSeconds(10)
        );
        InventoryRewardResult second = service.rewardEventMaterial(
                "user-1",
                reward,
                "echo-vault-v1:resolve-2",
                NOW.plusSeconds(20)
        );

        assertEquals(first, replayed);
        assertEquals(2, first.quantityAfter());
        assertEquals(1, first.version());
        assertEquals(4, second.quantityAfter());
        assertEquals(2, second.version());
        assertEquals(1, service.findAll("user-1").size());
    }

    @Test
    void shouldRejectSameSourceWithDifferentReward() {
        service.rewardEventMaterial(
                "user-1",
                new InventoryRewardDefinition(
                        content.require(StarterInventoryContent.LUMEN_SHARD_ID),
                        2
                ),
                "same-source",
                NOW
        );

        assertThrows(
                InventoryLedgerConflictException.class,
                () -> service.rewardEventMaterial(
                        "user-1",
                        new InventoryRewardDefinition(
                                content.require(StarterInventoryContent.LUMEN_SHARD_ID),
                                3
                        ),
                        "same-source",
                        NOW.plusSeconds(1)
                )
        );
    }

    @Test
    void shouldRejectSameSourceWithDifferentItem() {
        service.rewardEventMaterial(
                "user-1",
                new InventoryRewardDefinition(
                        content.require(StarterInventoryContent.LUMEN_SHARD_ID),
                        2
                ),
                "same-event-source",
                NOW
        );

        assertThrows(
                InventoryLedgerConflictException.class,
                () -> service.rewardEventMaterial(
                        "user-1",
                        new InventoryRewardDefinition(
                                content.require(StarterInventoryContent.ECHO_THREAD_ID),
                                1
                        ),
                        "same-event-source",
                        NOW.plusSeconds(1)
                )
        );
    }
}
