package com.walkingrpg.backend.platform.application;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

import com.walkingrpg.backend.account.application.AccountDeletedException;
import com.walkingrpg.backend.platform.push.PushDeliveryProvider;
import com.walkingrpg.backend.platform.push.PushDeliveryResult;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

@SpringBootTest
@ActiveProfiles("test")
@Testcontainers
@Import(AccountDeletionIntegrationTest.BlockingPushConfiguration.class)
class AccountDeletionIntegrationTest {

    private static final Instant NOW = Instant.parse("2026-07-29T05:00:00Z");

    @Container
    static final PostgreSQLContainer POSTGRES =
            new PostgreSQLContainer("postgres:17-alpine");

    @DynamicPropertySource
    static void configureDatabase(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        registry.add("spring.datasource.username", POSTGRES::getUsername);
        registry.add("spring.datasource.password", POSTGRES::getPassword);
    }

    @Autowired
    private PlatformAdminService service;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private BlockingPushDeliveryProvider blockingPushDeliveryProvider;

    @BeforeEach
    void cleanDatabase() {
        jdbcTemplate.execute("TRUNCATE TABLE account_deletion_receipt, app_user CASCADE");
        blockingPushDeliveryProvider.reset();
    }

    @Test
    void shouldDeleteAccountDataAndReplayDurableReceipt() {
        seedAccount("delete-user");

        AccountDeletionReceipt first = service.requestAccountDeletion(
                "delete-user",
                "delete-request-1",
                "DELETE"
        );

        assertEquals("COMPLETED", first.status());
        assertFalse(first.replayed());
        assertEquals(0, rowCount("app_user"));
        assertEquals(0, rowCount("activity_sync_state"));
        assertEquals(0, rowCount("platform_event"));
        assertEquals(0, rowCount("first_journey_milestone"));
        assertEquals(0, rowCount("unique_inventory_item"));
        assertEquals(0, rowCount("processed_crafting_command"));
        assertEquals(0, rowCount("processed_crafting_ingredient"));
        assertEquals(0, rowCount("equipment_slot_state"));
        assertEquals(0, rowCount("processed_equipment_command"));
        assertEquals(1, rowCount("account_deletion_receipt"));
        assertNotEquals("delete-user", jdbcTemplate.queryForObject(
                "SELECT subject_hash FROM account_deletion_receipt",
                String.class
        ));

        AccountDeletionReceipt replay = service.requestAccountDeletion(
                "delete-user",
                "a-new-key-after-process-restart",
                "DELETE"
        );

        assertEquals(first.receiptId(), replay.receiptId());
        assertEquals(first.requestedAt(), replay.requestedAt());
        assertEquals(first.completedAt(), replay.completedAt());
        assertTrue(replay.replayed());
        assertEquals(1, rowCount("account_deletion_receipt"));

        assertThrows(
                AccountDeletedException.class,
                () -> service.recordEvent(
                        "delete-user",
                        "stale_session_event",
                        NOW.plusSeconds(1),
                        Map.of()
                )
        );
        assertEquals(0, rowCount("app_user"));
        assertEquals(0, rowCount("platform_event"));
    }

    @Test
    void shouldRequireExactDeletionConfirmationBeforeMutation() {
        seedAccount("safe-user");

        PlatformValidationException error = assertThrows(
                PlatformValidationException.class,
                () -> service.requestAccountDeletion(
                        "safe-user",
                        "delete-request-2",
                        "delete"
                )
        );

        assertEquals("confirmation", error.field());
        assertEquals(1, rowCount("app_user"));
        assertEquals(0, rowCount("account_deletion_receipt"));
    }

    @Test
    void shouldExportEveryAccountScopedDataCategory() {
        seedAccount("export-user");

        Map<String, Object> export = service.exportAccount("export-user");

        assertEquals(Set.of(
                "exportedAt",
                "user",
                "devices",
                "activity",
                "activityOperations",
                "riskAssessments",
                "wallet",
                "economyLedger",
                "expedition",
                "expeditionOperations",
                "pilotProgress",
                "petProgress",
                "eventResolutions",
                "inventory",
                "inventoryLedger",
                "uniqueInventory",
                "craftingOperations",
                "craftingIngredients",
                "equipment",
                "equipmentOperations",
                "platformState",
                "platformCommands",
                "firstJourneyMilestones",
                "squadMembership",
                "telemetry",
                "crashReports",
                "pushRegistrations",
                "payments",
                "testerCohorts"
        ), export.keySet());
        assertEquals(1, ((List<?>) export.get("user")).size());
        assertEquals(1, ((List<?>) export.get("devices")).size());
        assertEquals(1, ((List<?>) export.get("activity")).size());
        assertEquals(1, ((List<?>) export.get("telemetry")).size());
        assertEquals(1, ((List<?>) export.get("firstJourneyMilestones")).size());
        assertEquals(1, ((List<?>) export.get("uniqueInventory")).size());
        assertEquals(1, ((List<?>) export.get("craftingOperations")).size());
        assertEquals(1, ((List<?>) export.get("craftingIngredients")).size());
        assertEquals(1, ((List<?>) export.get("equipment")).size());
        assertEquals(1, ((List<?>) export.get("equipmentOperations")).size());
    }

    @Test
    void shouldSerializeTestPushWithDeletionForSameSubject() throws Exception {
        seedAccount("push-race-user");
        blockingPushDeliveryProvider.blockNextSend();

        try (ExecutorService executor = Executors.newFixedThreadPool(2)) {
            Future<PushDeliveryResult> push = executor.submit(() -> service.sendTestPush(
                    "push-race-user",
                    "Test title",
                    "Test body"
            ));
            assertTrue(blockingPushDeliveryProvider.awaitSend(5, TimeUnit.SECONDS));
            assertTrue(blockingPushDeliveryProvider.transactionActiveDuringSend());

            Future<AccountDeletionReceipt> deletion = executor.submit(
                    () -> service.requestAccountDeletion(
                            "push-race-user",
                            "push-race-deletion",
                            "DELETE"
                    )
            );

            try {
                assertThrows(
                        TimeoutException.class,
                        () -> deletion.get(250, TimeUnit.MILLISECONDS)
                );
            } finally {
                blockingPushDeliveryProvider.releaseSend();
            }

            assertTrue(push.get(5, TimeUnit.SECONDS).accepted());
            assertEquals(
                    "COMPLETED",
                    deletion.get(5, TimeUnit.SECONDS).status()
            );
        }

        assertEquals(0, rowCount("app_user"));
        assertEquals(0, rowCount("platform_event"));
        assertEquals(1, rowCount("account_deletion_receipt"));
    }

    private void seedAccount(String userId) {
        Timestamp timestamp = Timestamp.from(NOW);
        jdbcTemplate.update(
                "INSERT INTO app_user (user_id, created_at, last_seen_at) VALUES (?, ?, ?)",
                userId,
                timestamp,
                timestamp
        );
        jdbcTemplate.update("""
                INSERT INTO app_device (
                    user_id, device_id, created_at, last_seen_at
                ) VALUES (?, 'delete-device', ?, ?)
                """, userId, timestamp, timestamp);
        jdbcTemplate.update("""
                INSERT INTO activity_sync_state (
                    user_id, local_date, accepted_total, state_version,
                    time_zone, updated_at
                ) VALUES (?, '2026-07-29', 1234, 1, 'Europe/Berlin', ?)
                """, userId, timestamp);
        jdbcTemplate.update("""
                INSERT INTO platform_event (
                    user_id, event_name, occurred_at, attributes, received_at
                ) VALUES (?, 'account_delete_test', ?, '{}'::jsonb, ?)
                """, userId, timestamp, timestamp);
        jdbcTemplate.update("""
                INSERT INTO first_journey_milestone (
                    user_id, milestone, occurred_at, source, attributes, recorded_at
                ) VALUES (
                    ?, 'JOURNEY_STARTED', ?, 'AUTHORITATIVE', '{}'::jsonb, ?
                )
                """, userId, timestamp, timestamp);
        jdbcTemplate.update("""
                INSERT INTO unique_inventory_item (
                    item_instance_id, user_id, item_id, recipe_id,
                    recipe_version, version, crafted_at
                ) VALUES (
                    '70000000-0000-0000-0000-000000000001', ?,
                    'resonance-compass', 'resonance-compass-v1', '1', 1, ?
                )
                """, userId, timestamp);
        jdbcTemplate.update("""
                INSERT INTO processed_crafting_command (
                    user_id, recipe_id, idempotency_key, request_fingerprint,
                    content_version, recipe_version, recipe_name,
                    item_instance_id, result_item_id, result_item_name,
                    result_item_description, result_item_version, crafted_at,
                    server_time, created_at
                ) VALUES (
                    ?, 'resonance-compass-v1', 'account-test-craft',
                    repeat('9', 64), 'crafting-v1', '1',
                    'Собрать резонансный компас',
                    '70000000-0000-0000-0000-000000000001',
                    'resonance-compass', 'Резонансный компас',
                    'Account export test item.', 1, ?, ?, ?
                )
                """, userId, timestamp, timestamp, timestamp);
        jdbcTemplate.update("""
                INSERT INTO equipment_slot_state (
                    user_id, slot_id, item_instance_id,
                    version, equipped_at, updated_at
                ) VALUES (
                    ?, 'NAVIGATION',
                    '70000000-0000-0000-0000-000000000001',
                    1, ?, ?
                )
                """, userId, timestamp, timestamp);
        jdbcTemplate.update("""
                INSERT INTO processed_equipment_command (
                    user_id, slot_id, idempotency_key, request_fingerprint,
                    content_version, action, changed, slot_name,
                    slot_description, equipment_version, item_instance_id,
                    item_id, item_name, item_description, equipped_at,
                    server_time, created_at
                ) VALUES (
                    ?, 'NAVIGATION', 'account-test-equip', repeat('8', 64),
                    'equipment-v1', 'EQUIP', true, 'Навигационный прибор',
                    'Account export equipment slot.', 1,
                    '70000000-0000-0000-0000-000000000001',
                    'resonance-compass', 'Резонансный компас',
                    'Account export test item.', ?, ?, ?
                )
                """, userId, timestamp, timestamp, timestamp);
        jdbcTemplate.update("""
                INSERT INTO processed_crafting_ingredient (
                    user_id, recipe_id, idempotency_key, item_id, item_name,
                    quantity_consumed, quantity_after, inventory_version
                ) VALUES (
                    ?, 'resonance-compass-v1', 'account-test-craft',
                    'lumen-shard', 'Люминовый осколок', 2, 0, 1
                )
                """, userId);
    }

    private int rowCount(String table) {
        Integer count = jdbcTemplate.queryForObject(
                "SELECT count(*) FROM " + table,
                Integer.class
        );
        return count == null ? 0 : count;
    }

    @TestConfiguration(proxyBeanMethods = false)
    static class BlockingPushConfiguration {

        @Bean
        @Primary
        BlockingPushDeliveryProvider blockingPushDeliveryProvider() {
            return new BlockingPushDeliveryProvider();
        }
    }

    static final class BlockingPushDeliveryProvider implements PushDeliveryProvider {

        private volatile CountDownLatch sendStarted;
        private volatile CountDownLatch sendRelease;
        private volatile boolean transactionActiveDuringSend;

        void reset() {
            sendStarted = null;
            sendRelease = null;
            transactionActiveDuringSend = false;
        }

        void blockNextSend() {
            sendStarted = new CountDownLatch(1);
            sendRelease = new CountDownLatch(1);
        }

        boolean awaitSend(long timeout, TimeUnit unit) throws InterruptedException {
            CountDownLatch started = sendStarted;
            return started != null && started.await(timeout, unit);
        }

        void releaseSend() {
            CountDownLatch release = sendRelease;
            if (release != null) {
                release.countDown();
            }
        }

        boolean transactionActiveDuringSend() {
            return transactionActiveDuringSend;
        }

        @Override
        public boolean isAvailable() {
            return true;
        }

        @Override
        public PushDeliveryResult send(String userId, String title, String body) {
            CountDownLatch started = sendStarted;
            CountDownLatch release = sendRelease;
            transactionActiveDuringSend =
                    TransactionSynchronizationManager.isActualTransactionActive();
            if (started != null && release != null) {
                started.countDown();
                try {
                    if (!release.await(10, TimeUnit.SECONDS)) {
                        throw new IllegalStateException(
                                "Timed out waiting to release test push"
                        );
                    }
                } catch (InterruptedException exception) {
                    Thread.currentThread().interrupt();
                    throw new IllegalStateException(
                            "Interrupted while waiting to release test push",
                            exception
                    );
                }
            }
            return new PushDeliveryResult("TEST", true, "test-push");
        }
    }
}
