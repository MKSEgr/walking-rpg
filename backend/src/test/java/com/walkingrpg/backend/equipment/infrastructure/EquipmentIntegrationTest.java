package com.walkingrpg.backend.equipment.infrastructure;

import com.walkingrpg.backend.testsupport.PostgresTestContainer;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

import com.walkingrpg.backend.account.application.AccountDeletedException;
import com.walkingrpg.backend.equipment.application.EquipmentService;
import com.walkingrpg.backend.equipment.application.StarterEquipmentContent;
import com.walkingrpg.backend.equipment.domain.EquipmentAction;
import com.walkingrpg.backend.equipment.domain.EquipmentCommand;
import com.walkingrpg.backend.equipment.domain.EquipmentResult;
import com.walkingrpg.backend.expedition.application.EventResolutionService;
import com.walkingrpg.backend.expedition.application.EventResolutionValidationException;
import com.walkingrpg.backend.expedition.application.PendingEventResultException;
import com.walkingrpg.backend.expedition.application.StarterExpeditionContent;
import com.walkingrpg.backend.expedition.domain.EventIdempotencyScope;
import com.walkingrpg.backend.expedition.domain.EventNextNodeResult;
import com.walkingrpg.backend.expedition.domain.EventPetRewardResult;
import com.walkingrpg.backend.expedition.domain.EventPilotRewardResult;
import com.walkingrpg.backend.expedition.domain.EventResolutionCommand;
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
import org.springframework.dao.DataIntegrityViolationException;
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
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

@SpringBootTest
@ActiveProfiles("test")
@Testcontainers
class EquipmentIntegrationTest {

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
    private EquipmentService equipmentService;

    @Autowired
    private HomeService homeService;

    @Autowired
    private EventResolutionService eventResolutionService;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private EquipmentRepository equipmentRepository;

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
        jdbcTemplate.update("DELETE FROM processed_equipment_command");
        jdbcTemplate.update("DELETE FROM equipment_slot_state");
        jdbcTemplate.update("DELETE FROM unique_inventory_item");
        jdbcTemplate.update("DELETE FROM app_device");
        jdbcTemplate.update("DELETE FROM app_user");
        jdbcTemplate.update("UPDATE content_release SET is_active = false WHERE is_active");
        jdbcTemplate.update("""
                UPDATE content_release
                SET is_active = true
                WHERE content_version = 'chapter-1-v1'
                """);
    }

    @Test
    void shouldPersistExactReplayAndProjectEquippedUniqueItemInHome() {
        activateResonanceRoute();
        UUID itemInstanceId = seedUniqueItem("equipment-user");
        seedMirrorDeltaEvent("equipment-user");
        HomeSnapshotResponse lockedHome = homeService.getSnapshot(new HomeQuery(
                "equipment-user",
                LocalDate.of(2026, 8, 1)
        ));
        assertFalse(lockedHome.expedition().unlockedEvent().choices().stream()
                .anyMatch(choice -> StarterExpeditionContent
                        .RESONANCE_ROUTE_CHOICE_ID.equals(choice.choiceId())));
        assertTrue(lockedHome.expedition().unlockedEvent().lockedChoices().stream()
                .anyMatch(choice -> StarterExpeditionContent
                        .RESONANCE_ROUTE_CHOICE_ID.equals(choice.choiceId())));

        EquipmentCommand command = command(
                "equipment-user",
                EquipmentAction.EQUIP,
                itemInstanceId,
                "equip-1"
        );

        EquipmentResult first = equipmentService.change(command);
        EquipmentResult replay = equipmentService.change(command);

        assertEquals(first, replay);
        assertEquals(1, rowCount("equipment_slot_state"));
        assertEquals(1, rowCount("processed_equipment_command"));
        assertEquals(1, first.version());

        HomeSnapshotResponse home = homeService.getSnapshot(new HomeQuery(
                "equipment-user",
                LocalDate.of(2026, 8, 1)
        ));
        assertEquals("EQUIPPED", home.equipment().getFirst().status());
        assertEquals(itemInstanceId,
                home.equipment().getFirst().item().itemInstanceId());
        assertEquals(
                StarterEquipmentContent.NAVIGATION_SLOT_ID,
                home.inventory().getFirst().equippedSlotId()
        );
        assertTrue(home.expedition().unlockedEvent().choices().stream()
                .anyMatch(choice -> StarterExpeditionContent
                        .RESONANCE_ROUTE_CHOICE_ID.equals(choice.choiceId())));
        assertTrue(home.expedition().unlockedEvent().lockedChoices().isEmpty());

        EquipmentResult unequipped = equipmentService.change(command(
                "equipment-user",
                EquipmentAction.UNEQUIP,
                null,
                "unequip-1"
        ));
        assertEquals(2, unequipped.version());
        assertFalse(equipmentService.isEquipped(
                "equipment-user",
                StarterEquipmentContent.NAVIGATION_SLOT_ID,
                StarterInventoryContent.RESONANCE_COMPASS_ID
        ));
    }

    @Test
    void shouldEvaluateEquippedUniqueItemMinimumUpgradeLevel() {
        String userId = "calibrated-equipment-user";
        UUID itemInstanceId = UUID.randomUUID();
        jdbcTemplate.update("""
                INSERT INTO app_user (user_id, created_at, last_seen_at)
                VALUES (?, now(), now())
                """, userId);
        jdbcTemplate.update("""
                INSERT INTO unique_inventory_item (
                    item_instance_id,
                    user_id,
                    item_id,
                    recipe_id,
                    recipe_version,
                    version,
                    crafted_at
                ) VALUES (?, ?, 'prism-sextant', 'prism-sextant-v1',
                          '1', 1, now())
                """, itemInstanceId, userId);
        equipmentService.change(command(
                userId,
                EquipmentAction.EQUIP,
                itemInstanceId,
                "equip-prism-sextant"
        ));
        jdbcTemplate.update("UPDATE content_release SET is_active = false WHERE is_active");
        assertEquals(1, jdbcTemplate.update("""
                UPDATE content_release
                SET is_active = true,
                    activated_at = COALESCE(activated_at, now())
                WHERE content_version = 'chapter-1-v6'
                """));
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
                ) VALUES (?, ?, ?, 50, 50, 'EVENT_READY', ?, 35, now(), now())
                """,
                userId,
                StarterExpeditionContent.EXPEDITION_ID,
                StarterExpeditionContent.SPECTRUM_OBSERVATORY_NODE_ID,
                StarterExpeditionContent.SPECTRUM_OBSERVATORY_EVENT_ID
        );

        assertTrue(equipmentService.isEquipped(
                userId,
                StarterEquipmentContent.NAVIGATION_SLOT_ID,
                StarterInventoryContent.PRISM_SEXTANT_ID,
                1
        ));
        assertFalse(equipmentService.isEquipped(
                userId,
                StarterEquipmentContent.NAVIGATION_SLOT_ID,
                StarterInventoryContent.PRISM_SEXTANT_ID,
                2
        ));
        HomeSnapshotResponse locked = homeService.getSnapshot(new HomeQuery(
                userId,
                LocalDate.of(2026, 8, 15)
        ));
        assertTrue(locked.expedition().unlockedEvent().lockedChoices().stream()
                .anyMatch(choice -> StarterExpeditionContent
                        .CALIBRATED_SEXTANT_CHOICE_ID.equals(choice.choiceId())
                        && choice.requirement().minimumUpgradeLevel() == 2));

        jdbcTemplate.update("""
                UPDATE unique_inventory_item
                SET version = 2,
                    rarity = 'RARE',
                    upgraded_at = now()
                WHERE user_id = ?
                  AND item_instance_id = ?
                """, userId, itemInstanceId);

        assertTrue(equipmentService.isEquipped(
                userId,
                StarterEquipmentContent.NAVIGATION_SLOT_ID,
                StarterInventoryContent.PRISM_SEXTANT_ID,
                2
        ));
        HomeSnapshotResponse available = homeService.getSnapshot(new HomeQuery(
                userId,
                LocalDate.of(2026, 8, 15)
        ));
        assertTrue(available.expedition().unlockedEvent().choices().stream()
                .anyMatch(choice -> StarterExpeditionContent
                        .CALIBRATED_SEXTANT_CHOICE_ID.equals(choice.choiceId())));

        jdbcTemplate.update("""
                UPDATE expedition_progress
                SET current_node_id = ?,
                    progress_energy = 130,
                    required_energy = 130,
                    status = 'EVENT_READY',
                    unlocked_event_id = ?,
                    version = 36,
                    updated_at = now()
                WHERE user_id = ?
                """,
                StarterExpeditionContent.FINAL_NODE_ID,
                StarterExpeditionContent.FINAL_EVENT_ID,
                userId
        );
        HomeSnapshotResponse v6Finale = homeService.getSnapshot(new HomeQuery(
                userId,
                LocalDate.of(2026, 8, 15)
        ));
        assertFalse(v6Finale.expedition().unlockedEvent().choices().stream()
                .anyMatch(choice -> StarterExpeditionContent
                        .SECOND_DAWN_ROUTE_CHOICE_ID.equals(choice.choiceId())));
        assertFalse(v6Finale.expedition().unlockedEvent().lockedChoices().stream()
                .anyMatch(choice -> StarterExpeditionContent
                        .SECOND_DAWN_ROUTE_CHOICE_ID.equals(choice.choiceId())));

        jdbcTemplate.update(
                "UPDATE content_release SET is_active = false WHERE is_active"
        );
        assertEquals(1, jdbcTemplate.update("""
                UPDATE content_release
                SET is_active = true,
                    activated_at = COALESCE(activated_at, now())
                WHERE content_version = 'chapter-1-v7'
                """));
        HomeSnapshotResponse v7Finale = homeService.getSnapshot(new HomeQuery(
                userId,
                LocalDate.of(2026, 8, 15)
        ));
        assertTrue(v7Finale.expedition().unlockedEvent().choices().stream()
                .anyMatch(choice -> StarterExpeditionContent
                        .SECOND_DAWN_ROUTE_CHOICE_ID.equals(choice.choiceId())));
    }

    @Test
    void shouldHideAndRejectResonanceRouteUntilClusterActivation() {
        String userId = "staged-resonance-user";
        UUID itemInstanceId = seedUniqueItem(userId);
        seedMirrorDeltaEvent(userId);
        equipmentService.change(command(
                userId,
                EquipmentAction.EQUIP,
                itemInstanceId,
                "equip-before-activation"
        ));

        HomeSnapshotResponse staged = homeService.getSnapshot(new HomeQuery(
                userId,
                LocalDate.of(2026, 8, 1)
        ));
        assertEquals(
                StarterExpeditionContent.LEGACY_CONTENT_VERSION,
                staged.contentVersion()
        );
        assertFalse(staged.expedition().unlockedEvent().choices().stream()
                .anyMatch(choice -> StarterExpeditionContent
                        .RESONANCE_ROUTE_CHOICE_ID.equals(choice.choiceId())));
        assertFalse(staged.expedition().unlockedEvent().lockedChoices().stream()
                .anyMatch(choice -> StarterExpeditionContent
                        .RESONANCE_ROUTE_CHOICE_ID.equals(choice.choiceId())));

        assertThrows(
                EventResolutionValidationException.class,
                () -> eventResolutionService.resolve(new EventResolutionCommand(
                        userId,
                        StarterExpeditionContent.MIRROR_DELTA_EVENT_ID,
                        StarterExpeditionContent.RESONANCE_ROUTE_CHOICE_ID,
                        "route-before-activation"
                ))
        );
        assertEquals(0, rowCount("processed_event_resolution"));
        assertEquals(
                StarterExpeditionContent.MIRROR_DELTA_NODE_ID,
                jdbcTemplate.queryForObject("""
                        SELECT current_node_id
                        FROM expedition_progress
                        WHERE user_id = ?
                        """, String.class, userId)
        );

        activateResonanceRoute();
        HomeSnapshotResponse active = homeService.getSnapshot(new HomeQuery(
                userId,
                LocalDate.of(2026, 8, 1)
        ));
        assertEquals(StarterExpeditionContent.CONTENT_VERSION, active.contentVersion());
        assertTrue(active.expedition().unlockedEvent().choices().stream()
                .anyMatch(choice -> StarterExpeditionContent
                        .RESONANCE_ROUTE_CHOICE_ID.equals(choice.choiceId())));
    }

    @Test
    void shouldPersistExactEmptyUnequipForFirstWriteUser() {
        String userId = "equipment-first-write-user";
        EquipmentCommand command = command(
                userId,
                EquipmentAction.UNEQUIP,
                null,
                "first-empty-unequip"
        );

        EquipmentResult first = equipmentService.change(command);
        EquipmentResult replay = equipmentService.change(command);

        assertEquals(first, replay);
        assertFalse(first.changed());
        assertEquals(0, first.version());
        assertNull(first.equippedItem());
        assertEquals(1, rowCount("app_user"));
        assertEquals(0, rowCount("equipment_slot_state"));
        assertEquals(1, rowCount("processed_equipment_command"));
    }

    @Test
    void shouldSerializeConcurrentExactEquipReplay() throws Exception {
        UUID itemInstanceId = seedUniqueItem("equipment-replay-race-user");
        EquipmentCommand command = command(
                "equipment-replay-race-user",
                EquipmentAction.EQUIP,
                itemInstanceId,
                "concurrent-exact-equip"
        );
        CountDownLatch start = new CountDownLatch(1);

        try (ExecutorService executor = Executors.newFixedThreadPool(2)) {
            Future<EquipmentResult> first = executor.submit(() -> {
                await(start, "Concurrent equip не запущен");
                return equipmentService.change(command);
            });
            Future<EquipmentResult> second = executor.submit(() -> {
                await(start, "Concurrent equip не запущен");
                return equipmentService.change(command);
            });

            start.countDown();
            EquipmentResult firstResult = first.get(10, TimeUnit.SECONDS);
            EquipmentResult secondResult = second.get(10, TimeUnit.SECONDS);
            assertEquals(firstResult, secondResult);
        }

        assertEquals(1, rowCount("equipment_slot_state"));
        assertEquals(1, rowCount("processed_equipment_command"));
        assertEquals(1, jdbcTemplate.queryForObject("""
                SELECT version
                FROM equipment_slot_state
                WHERE user_id = 'equipment-replay-race-user'
                  AND slot_id = 'NAVIGATION'
                """, Integer.class));
    }

    @Test
    void shouldEnforceOwnedItemForeignKeyAndDeleteEquipmentWithAccount() {
        UUID itemInstanceId = seedUniqueItem("owner-user");
        jdbcTemplate.update("""
                INSERT INTO app_user (user_id, created_at, last_seen_at)
                VALUES ('other-user', now(), now())
                """);

        assertThrows(DataIntegrityViolationException.class, () -> jdbcTemplate.update("""
                INSERT INTO equipment_slot_state (
                    user_id, slot_id, item_instance_id,
                    version, equipped_at, updated_at
                ) VALUES (?, 'NAVIGATION', ?, 1, now(), now())
                """, "other-user", itemInstanceId));

        equipmentService.change(command(
                "owner-user",
                EquipmentAction.EQUIP,
                itemInstanceId,
                "equip-owner"
        ));
        jdbcTemplate.update("DELETE FROM app_user WHERE user_id = 'owner-user'");
        assertEquals(0, rowCount("equipment_slot_state"));
        assertEquals(0, rowCount("processed_equipment_command"));
    }

    @Test
    void shouldSerializeEquipmentBoundaryWithAccountDeletion() throws Exception {
        String userId = "equipment-deletion-race-user";
        UUID itemInstanceId = seedUniqueItem(userId);
        CountDownLatch boundaryHeld = new CountDownLatch(1);
        CountDownLatch releaseBoundary = new CountDownLatch(1);
        TransactionTemplate transactions = new TransactionTemplate(
                transactionManager
        );

        try (ExecutorService executor = Executors.newFixedThreadPool(2)) {
            Future<?> equipmentBoundary = executor.submit(() ->
                    transactions.executeWithoutResult(status -> {
                        equipmentRepository.acquireLock(userId);
                        boundaryHeld.countDown();
                        await(
                                releaseBoundary,
                                "Equipment boundary не освобождён"
                        );
                    })
            );
            assertTrue(boundaryHeld.await(10, TimeUnit.SECONDS));

            Future<AccountDeletionReceipt> deletion = executor.submit(() ->
                    platformAdminService.requestAccountDeletion(
                            userId,
                            "delete-during-equipment",
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

            equipmentBoundary.get(10, TimeUnit.SECONDS);
            assertEquals(
                    "COMPLETED",
                    deletion.get(10, TimeUnit.SECONDS).status()
            );
        }

        assertThrows(
                AccountDeletedException.class,
                () -> equipmentService.change(command(
                        userId,
                        EquipmentAction.EQUIP,
                        itemInstanceId,
                        "after-deletion"
                ))
        );
        assertEquals(0, rowCount("unique_inventory_item"));
        assertEquals(0, rowCount("equipment_slot_state"));
        assertEquals(0, rowCount("processed_equipment_command"));
    }

    @Test
    void shouldWaitForEventBoundaryAndRejectEquipmentAfterPendingCommit()
            throws Exception {
        String userId = "equipment-pending-race-user";
        UUID itemInstanceId = seedUniqueItem(userId);
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
                                        "pending-before-equipment"
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

            Future<EquipmentResult> equipment = executor.submit(() ->
                    equipmentService.change(command(
                            userId,
                            EquipmentAction.EQUIP,
                            itemInstanceId,
                            "equip-after-event"
                    ))
            );
            try {
                assertThrows(
                        TimeoutException.class,
                        () -> equipment.get(250, TimeUnit.MILLISECONDS)
                );
            } finally {
                releaseBoundary.countDown();
            }

            eventBoundary.get(10, TimeUnit.SECONDS);
            ExecutionException failure = assertThrows(
                    ExecutionException.class,
                    () -> equipment.get(10, TimeUnit.SECONDS)
            );
            assertTrue(failure.getCause() instanceof PendingEventResultException);
            PendingEventResultException error =
                    (PendingEventResultException) failure.getCause();
            assertEquals(pending.result().receiptId(), error.receiptId());
            assertEquals(pending.result().eventId(), error.eventId());
        }

        assertEquals(0, rowCount("equipment_slot_state"));
        assertEquals(0, rowCount("processed_equipment_command"));
    }

    private UUID seedUniqueItem(String userId) {
        UUID itemInstanceId = UUID.randomUUID();
        jdbcTemplate.update("""
                INSERT INTO app_user (user_id, created_at, last_seen_at)
                VALUES (?, now(), now())
                """, userId);
        jdbcTemplate.update("""
                INSERT INTO unique_inventory_item (
                    item_instance_id,
                    user_id,
                    item_id,
                    recipe_id,
                    recipe_version,
                    version,
                    crafted_at
                ) VALUES (?, ?, ?, 'resonance-compass-v1', '1', 1, now())
                """,
                itemInstanceId,
                userId,
                StarterInventoryContent.RESONANCE_COMPASS_ID
        );
        return itemInstanceId;
    }

    private EquipmentCommand command(
            String userId,
            EquipmentAction action,
            UUID itemInstanceId,
            String key
    ) {
        return new EquipmentCommand(
                userId,
                StarterEquipmentContent.NAVIGATION_SLOT_ID,
                action,
                itemInstanceId,
                key
        );
    }

    private void seedMirrorDeltaEvent(String userId) {
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
                ) VALUES (?, ?, ?, 95, 95, 'EVENT_READY', ?, 1, now(), now())
                """,
                userId,
                StarterExpeditionContent.EXPEDITION_ID,
                StarterExpeditionContent.MIRROR_DELTA_NODE_ID,
                StarterExpeditionContent.MIRROR_DELTA_EVENT_ID
        );
    }

    private void activateResonanceRoute() {
        jdbcTemplate.update("UPDATE content_release SET is_active = false WHERE is_active");
        assertEquals(1, jdbcTemplate.update("""
                UPDATE content_release
                SET is_active = true,
                    activated_at = COALESCE(activated_at, now())
                WHERE content_version = 'chapter-1-v2'
                """));
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
                        UUID.fromString(
                                "20000000-0000-0000-0000-000000000001"
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

    private void await(CountDownLatch latch, String timeoutMessage) {
        try {
            if (!latch.await(10, TimeUnit.SECONDS)) {
                throw new IllegalStateException(timeoutMessage);
            }
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException(
                    "Ожидание equipment boundary прервано",
                    exception
            );
        }
    }

    private int rowCount(String table) {
        Integer count = jdbcTemplate.queryForObject(
                "SELECT count(*) FROM " + table,
                Integer.class
        );
        return count == null ? 0 : count;
    }
}
