package com.walkingrpg.backend.crafting.infrastructure;

import com.walkingrpg.backend.testsupport.PostgresTestContainer;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

import com.walkingrpg.backend.account.application.AccountDeletedException;
import com.walkingrpg.backend.crafting.application.CraftingService;
import com.walkingrpg.backend.crafting.application.CraftingStateConflictException;
import com.walkingrpg.backend.crafting.application.InsufficientCraftingMaterialsException;
import com.walkingrpg.backend.crafting.application.StarterCraftingContent;
import com.walkingrpg.backend.crafting.domain.CraftingCommand;
import com.walkingrpg.backend.crafting.domain.CraftingResult;
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
import com.walkingrpg.backend.expedition.infrastructure.EventResolutionRepository;
import com.walkingrpg.backend.expedition.infrastructure.ExpeditionRepository;
import com.walkingrpg.backend.home.api.HomeSnapshotResponse;
import com.walkingrpg.backend.home.application.HomeService;
import com.walkingrpg.backend.home.domain.HomeQuery;
import com.walkingrpg.backend.inventory.application.StarterInventoryContent;
import com.walkingrpg.backend.platform.application.AccountDeletionReceipt;
import com.walkingrpg.backend.platform.application.PlatformAdminService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

@SpringBootTest
@ActiveProfiles("test")
@Testcontainers
class CraftingIntegrationTest {

    @Container
    static final PostgreSQLContainer POSTGRES =
            PostgresTestContainer.create();

    @DynamicPropertySource
    static void configureDatabase(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        registry.add("spring.datasource.username", POSTGRES::getUsername);
        registry.add("spring.datasource.password", POSTGRES::getPassword);
    }

    @Autowired
    private CraftingService craftingService;

    @Autowired
    private HomeService homeService;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private CraftingRepository craftingRepository;

    @Autowired
    private ExpeditionRepository expeditionRepository;

    @Autowired
    private EventResolutionRepository eventResolutionRepository;

    @Autowired
    private PlatformAdminService platformAdminService;

    @Autowired
    private PlatformTransactionManager transactionManager;

    @BeforeEach
    void cleanDatabase() {
        jdbcTemplate.update("DELETE FROM account_deletion_receipt");
        jdbcTemplate.update("DELETE FROM processed_crafting_ingredient");
        jdbcTemplate.update("DELETE FROM processed_crafting_command");
        jdbcTemplate.update("DELETE FROM unique_inventory_item");
        jdbcTemplate.update("DELETE FROM inventory_ledger");
        jdbcTemplate.update("DELETE FROM inventory_stack");
        jdbcTemplate.update("DELETE FROM app_device");
        jdbcTemplate.update("DELETE FROM app_user");
    }

    @Test
    void shouldPersistExactReplayAndProjectCraftingStateInHome() {
        seedMaterials("craft-user", 3, 2);
        CraftingCommand command = command("craft-user", "craft-1");

        CraftingResult created = craftingService.craft(command);
        CraftingResult replayed = craftingService.craft(command);

        assertEquals(created, replayed);
        assertEquals(1, rowCount("unique_inventory_item"));
        assertEquals(1, rowCount("processed_crafting_command"));
        assertEquals(2, rowCount("processed_crafting_ingredient"));
        assertEquals(2, rowCount("inventory_ledger"));
        assertEquals(-3L, jdbcTemplate.queryForObject("""
                SELECT sum(quantity_delta)
                FROM inventory_ledger
                WHERE user_id = 'craft-user'
                  AND source_type = 'CRAFTING_COMMAND'
                """, Long.class));
        assertEquals(1, materialQuantity(
                "craft-user",
                StarterInventoryContent.LUMEN_SHARD_ID
        ));
        assertEquals(1, materialQuantity(
                "craft-user",
                StarterInventoryContent.ECHO_THREAD_ID
        ));

        HomeSnapshotResponse home = homeService.getSnapshot(new HomeQuery(
                "craft-user",
                LocalDate.of(2026, 8, 1)
        ));
        assertEquals(3, home.inventory().size());
        assertEquals(1, home.inventory().stream()
                .filter(item -> item.itemId().equals(
                        StarterInventoryContent.RESONANCE_COMPASS_ID
                ))
                .filter(item -> item.kind().equals("UNIQUE"))
                .count());
        assertEquals(1, home.craftingRecipes().size());
        assertEquals("CRAFTED", home.craftingRecipes().getFirst().status());

        assertThrows(
                CraftingStateConflictException.class,
                () -> craftingService.craft(command("craft-user", "craft-2"))
        );
        assertEquals(2, rowCount("inventory_ledger"));
    }

    @Test
    void shouldRollBackWhenAnyIngredientIsMissing() {
        seedMaterials("missing-user", 1, 0);

        InsufficientCraftingMaterialsException error = assertThrows(
                InsufficientCraftingMaterialsException.class,
                () -> craftingService.craft(command("missing-user", "missing"))
        );

        assertEquals(2, error.shortages().size());
        assertEquals(1, materialQuantity(
                "missing-user",
                StarterInventoryContent.LUMEN_SHARD_ID
        ));
        assertEquals(0, rowCount("inventory_ledger"));
        assertEquals(0, rowCount("unique_inventory_item"));
        assertEquals(0, rowCount("processed_crafting_command"));
    }

    @Test
    void shouldReplayConcurrentSameKeyWithoutSecondDebit() throws Exception {
        seedMaterials("replay-race-user", 4, 2);
        CountDownLatch ready = new CountDownLatch(2);
        CountDownLatch start = new CountDownLatch(1);

        CraftingResult firstResult;
        CraftingResult secondResult;
        try (ExecutorService executor = Executors.newFixedThreadPool(2)) {
            Future<CraftingResult> first = executor.submit(() -> raceCraftResult(
                    "replay-race-user",
                    "same-key",
                    ready,
                    start
            ));
            Future<CraftingResult> second = executor.submit(() -> raceCraftResult(
                    "replay-race-user",
                    "same-key",
                    ready,
                    start
            ));
            assertTrue(ready.await(10, TimeUnit.SECONDS));
            start.countDown();

            firstResult = first.get(10, TimeUnit.SECONDS);
            secondResult = second.get(10, TimeUnit.SECONDS);
        }

        assertEquals(firstResult, secondResult);
        assertEquals(1, rowCount("unique_inventory_item"));
        assertEquals(1, rowCount("processed_crafting_command"));
        assertEquals(2, rowCount("inventory_ledger"));
        assertEquals(2, materialQuantity(
                "replay-race-user",
                StarterInventoryContent.LUMEN_SHARD_ID
        ));
        assertEquals(1, materialQuantity(
                "replay-race-user",
                StarterInventoryContent.ECHO_THREAD_ID
        ));
    }

    @Test
    void shouldSerializeConcurrentDifferentKeysAndDebitOnce() throws Exception {
        seedMaterials("race-user", 4, 2);
        CountDownLatch ready = new CountDownLatch(2);
        CountDownLatch start = new CountDownLatch(1);

        try (ExecutorService executor = Executors.newFixedThreadPool(2)) {
            Future<String> first = executor.submit(() -> raceCraft(
                    "race-user",
                    "race-1",
                    ready,
                    start
            ));
            Future<String> second = executor.submit(() -> raceCraft(
                    "race-user",
                    "race-2",
                    ready,
                    start
            ));
            assertTrue(ready.await(10, TimeUnit.SECONDS));
            start.countDown();

            List<String> outcomes = List.of(
                    first.get(10, TimeUnit.SECONDS),
                    second.get(10, TimeUnit.SECONDS)
            );
            assertTrue(outcomes.contains("CREATED"));
            assertTrue(outcomes.contains("ALREADY_CRAFTED"));
        }

        assertEquals(1, rowCount("unique_inventory_item"));
        assertEquals(1, rowCount("processed_crafting_command"));
        assertEquals(2, rowCount("inventory_ledger"));
        assertEquals(2, materialQuantity(
                "race-user",
                StarterInventoryContent.LUMEN_SHARD_ID
        ));
        assertEquals(1, materialQuantity(
                "race-user",
                StarterInventoryContent.ECHO_THREAD_ID
        ));
    }

    @Test
    void shouldSerializeCraftingBoundaryWithAccountDeletion() throws Exception {
        String userId = "craft-deletion-race-user";
        seedMaterials(userId, 3, 2);
        CountDownLatch boundaryHeld = new CountDownLatch(1);
        CountDownLatch releaseBoundary = new CountDownLatch(1);
        TransactionTemplate transactions = new TransactionTemplate(
                transactionManager
        );

        try (ExecutorService executor = Executors.newFixedThreadPool(2)) {
            Future<?> craftingBoundary = executor.submit(() ->
                    transactions.executeWithoutResult(status -> {
                        craftingRepository.acquireLock(userId);
                        boundaryHeld.countDown();
                        await(releaseBoundary, "Crafting boundary не освобождён");
                    })
            );
            assertTrue(boundaryHeld.await(10, TimeUnit.SECONDS));

            Future<AccountDeletionReceipt> deletion = executor.submit(() ->
                    platformAdminService.requestAccountDeletion(
                            userId,
                            "delete-during-craft",
                            "DELETE"
                    )
            );
            try {
                assertThrows(
                        TimeoutException.class,
                        () -> deletion.get(250, TimeUnit.MILLISECONDS)
                );
            } finally {
                releaseBoundary.countDown();
            }

            craftingBoundary.get(10, TimeUnit.SECONDS);
            assertEquals(
                    "COMPLETED",
                    deletion.get(10, TimeUnit.SECONDS).status()
            );
        }

        assertEquals(0, rowCount("app_user"));
        assertEquals(1, rowCount("account_deletion_receipt"));
        assertThrows(
                AccountDeletedException.class,
                () -> craftingService.craft(command(userId, "after-deletion"))
        );
        assertEquals(0, rowCount("unique_inventory_item"));
        assertEquals(0, rowCount("inventory_ledger"));
    }

    @Test
    void shouldWaitForEventBoundaryAndRejectCraftAfterPendingCommit()
            throws Exception {
        String userId = "craft-pending-race-user";
        seedMaterials(userId, 3, 2);
        seedResolvedEventState(userId);
        ProcessedEventResolution pending = pendingEventResult();
        CountDownLatch boundaryHeld = new CountDownLatch(1);
        CountDownLatch releaseBoundary = new CountDownLatch(1);
        TransactionTemplate transactions = new TransactionTemplate(
                transactionManager
        );

        try (ExecutorService executor = Executors.newFixedThreadPool(2)) {
            Future<?> eventBoundary = executor.submit(() ->
                    transactions.executeWithoutResult(status -> {
                        expeditionRepository.acquireLock(
                                userId,
                                StarterExpeditionContent.EXPEDITION_ID
                        );
                        eventResolutionRepository.saveProcessed(
                                new EventIdempotencyScope(
                                        userId,
                                        pending.result().eventId(),
                                        "pending-before-craft"
                                ),
                                pending
                        );
                        boundaryHeld.countDown();
                        await(
                                releaseBoundary,
                                "Event boundary не освобождён"
                        );
                    })
            );
            assertTrue(boundaryHeld.await(10, TimeUnit.SECONDS));

            Future<CraftingResult> crafting = executor.submit(() ->
                    craftingService.craft(command(userId, "craft-after-event"))
            );
            try {
                assertThrows(
                        TimeoutException.class,
                        () -> crafting.get(250, TimeUnit.MILLISECONDS)
                );
            } finally {
                releaseBoundary.countDown();
            }

            eventBoundary.get(10, TimeUnit.SECONDS);
            ExecutionException failure = assertThrows(
                    ExecutionException.class,
                    () -> crafting.get(10, TimeUnit.SECONDS)
            );
            assertTrue(failure.getCause() instanceof PendingEventResultException);
            PendingEventResultException error =
                    (PendingEventResultException) failure.getCause();
            assertEquals(pending.result().receiptId(), error.receiptId());
            assertEquals(pending.result().eventId(), error.eventId());
        }

        assertEquals(0, rowCount("unique_inventory_item"));
        assertEquals(0, rowCount("processed_crafting_command"));
        assertEquals(0, rowCount("inventory_ledger"));
        assertEquals(3, materialQuantity(
                userId,
                StarterInventoryContent.LUMEN_SHARD_ID
        ));
        assertEquals(2, materialQuantity(
                userId,
                StarterInventoryContent.ECHO_THREAD_ID
        ));
    }

    private CraftingResult raceCraftResult(
            String userId,
            String key,
            CountDownLatch ready,
            CountDownLatch start
    ) throws InterruptedException {
        ready.countDown();
        if (!start.await(10, TimeUnit.SECONDS)) {
            throw new IllegalStateException("Concurrent crafting не стартовал");
        }
        return craftingService.craft(command(userId, key));
    }

    private String raceCraft(
            String userId,
            String key,
            CountDownLatch ready,
            CountDownLatch start
    ) throws InterruptedException {
        ready.countDown();
        if (!start.await(10, TimeUnit.SECONDS)) {
            throw new IllegalStateException("Concurrent crafting не стартовал");
        }
        try {
            craftingService.craft(command(userId, key));
            return "CREATED";
        } catch (CraftingStateConflictException exception) {
            return "ALREADY_CRAFTED";
        }
    }

    private void await(CountDownLatch latch, String timeoutMessage) {
        try {
            if (!latch.await(10, TimeUnit.SECONDS)) {
                throw new IllegalStateException(timeoutMessage);
            }
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException(
                    "Ожидание crafting boundary прервано",
                    exception
            );
        }
    }

    private void seedMaterials(
            String userId,
            long lumenQuantity,
            long echoQuantity
    ) {
        jdbcTemplate.update("""
                INSERT INTO app_user (user_id, created_at, last_seen_at)
                VALUES (?, now(), now())
                """, userId);
        insertStack(
                userId,
                StarterInventoryContent.LUMEN_SHARD_ID,
                lumenQuantity
        );
        if (echoQuantity > 0) {
            insertStack(
                    userId,
                    StarterInventoryContent.ECHO_THREAD_ID,
                    echoQuantity
            );
        }
    }

    private void seedResolvedEventState(String userId) {
        jdbcTemplate.update("""
                INSERT INTO expedition_progress (
                    user_id,
                    expedition_id,
                    current_node_id,
                    progress_energy,
                    required_energy,
                    status,
                    unlocked_event_id,
                    version,
                    created_at,
                    updated_at
                )
                VALUES (?, ?, ?, 0, 45, 'IN_PROGRESS', NULL, 2, now(), now())
                """,
                userId,
                StarterExpeditionContent.EXPEDITION_ID,
                StarterExpeditionContent.SECOND_NODE_ID
        );
        jdbcTemplate.update("""
                INSERT INTO pilot_progress (
                    user_id,
                    pilot_id,
                    level,
                    current_experience,
                    next_level_experience,
                    version,
                    created_at,
                    updated_at
                )
                VALUES (?, 'navigator-v1', 1, 10, 100, 1, now(), now())
                """, userId);
        jdbcTemplate.update("""
                INSERT INTO pet_progress (
                    user_id,
                    pet_id,
                    level,
                    bond,
                    version,
                    created_at,
                    updated_at
                )
                VALUES (?, 'spark-v1', 1, 5, 1, now(), now())
                """, userId);
    }

    private ProcessedEventResolution pendingEventResult() {
        return new ProcessedEventResolution(
                "b".repeat(64),
                new EventResolutionResult(
                        UUID.fromString("20000000-0000-0000-0000-000000000001"),
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
                        Instant.parse("2026-08-01T08:00:00Z")
                )
        );
    }

    private void insertStack(String userId, String itemId, long quantity) {
        jdbcTemplate.update("""
                INSERT INTO inventory_stack (
                    user_id, item_id, quantity, version, created_at, updated_at
                )
                VALUES (?, ?, ?, 1, now(), now())
                """, userId, itemId, quantity);
    }

    private CraftingCommand command(String userId, String idempotencyKey) {
        return new CraftingCommand(
                userId,
                StarterCraftingContent.RESONANCE_COMPASS_RECIPE_ID,
                idempotencyKey
        );
    }

    private int rowCount(String table) {
        Integer count = jdbcTemplate.queryForObject(
                "SELECT count(*) FROM " + table,
                Integer.class
        );
        return count == null ? 0 : count;
    }

    private long materialQuantity(String userId, String itemId) {
        Long quantity = jdbcTemplate.queryForObject("""
                SELECT quantity
                FROM inventory_stack
                WHERE user_id = ?
                  AND item_id = ?
                """, Long.class, userId, itemId);
        return quantity == null ? 0 : quantity;
    }
}
