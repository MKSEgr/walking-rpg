package com.walkingrpg.backend.platform.application;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.Statement;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

import javax.sql.DataSource;

import com.zaxxer.hikari.HikariDataSource;
import com.walkingrpg.backend.account.application.AccountDeletedException;
import com.walkingrpg.backend.account.application.AccountDeletionRegistry;
import com.walkingrpg.backend.expedition.application.EventResultAcknowledgementService;
import com.walkingrpg.backend.expedition.application.ExpeditionAdvanceService;
import com.walkingrpg.backend.expedition.application.StarterExpeditionContent;
import com.walkingrpg.backend.expedition.domain.ExpeditionAdvanceCommand;
import com.walkingrpg.backend.expedition.domain.ExpeditionAdvanceResult;
import com.walkingrpg.backend.platform.api.PlatformCommandRequest;
import com.walkingrpg.backend.platform.api.PlatformCommandResponse;
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
import static org.junit.jupiter.api.Assertions.assertInstanceOf;
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
    private PlatformService platformService;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private DataSource dataSource;

    @Autowired
    private ExpeditionAdvanceService expeditionAdvanceService;

    @Autowired
    private EventResultAcknowledgementService acknowledgementService;

    @Autowired
    private BlockingPushDeliveryProvider blockingPushDeliveryProvider;

    @Autowired
    private MutableClock clock;

    @BeforeEach
    void cleanDatabase() {
        jdbcTemplate.execute("TRUNCATE TABLE account_deletion_receipt, app_user CASCADE");
        blockingPushDeliveryProvider.reset();
        clock.set(NOW);
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
        assertEquals(0, rowCount("platform_cosmetic_slot_state"));
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
                "cosmeticEquipment",
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
        assertEquals(1, ((List<?>) export.get("cosmeticEquipment")).size());
    }

    @Test
    void shouldAnchorAccountExportToOneDatabaseSnapshot() throws Exception {
        String userId = "consistent-export-user";
        seedAccount(userId);
        clock.set(Instant.EPOCH);
        Map<String, Object> duringConcurrentInsert;
        Instant observationStartedAt;
        Instant firstStatementFinishedAt;
        ExecutorService executor = Executors.newSingleThreadExecutor();

        try (Connection blocker = dataSource.getConnection()) {
            blocker.setAutoCommit(false);
            try (Statement lock = blocker.createStatement()) {
                lock.execute(
                        "LOCK TABLE first_journey_milestone IN ACCESS EXCLUSIVE MODE"
                );
            }

            observationStartedAt = databaseTime();
            Future<Map<String, Object>> pending = executor.submit(
                    () -> service.exportAccount(userId)
            );
            awaitAccountExportMilestoneReadBlock();
            firstStatementFinishedAt = databaseTime();

            try (PreparedStatement insertEvent = blocker.prepareStatement("""
                    INSERT INTO platform_event (
                        user_id, event_name, occurred_at,
                        attributes, received_at
                    ) VALUES (?, 'concurrent_export_event', ?, '{}'::jsonb, ?)
                    """)) {
                Timestamp eventTime = Timestamp.from(NOW.plusSeconds(60));
                insertEvent.setString(1, userId);
                insertEvent.setTimestamp(2, eventTime);
                insertEvent.setTimestamp(3, eventTime);
                insertEvent.executeUpdate();
            }
            blocker.commit();
            duringConcurrentInsert = pending.get(5, TimeUnit.SECONDS);
        } finally {
            executor.shutdownNow();
            executor.awaitTermination(5, TimeUnit.SECONDS);
        }

        assertEquals(1, ((List<?>) duringConcurrentInsert.get("telemetry")).size());
        assertSnapshotBoundary(
                observationStartedAt,
                (Instant) duringConcurrentInsert.get("exportedAt"),
                firstStatementFinishedAt
        );
        assertEquals(2, rowCount("platform_event"));

        Map<String, Object> afterInsert = service.exportAccount(userId);
        assertEquals(2, ((List<?>) afterInsert.get("telemetry")).size());
    }

    @Test
    void shouldExportWithOneConnectionAndReleaseSessionLock() {
        String userId = "single-connection-export-user";
        seedAccount(userId);

        try (HikariDataSource singleConnectionPool = new HikariDataSource()) {
            singleConnectionPool.setJdbcUrl(POSTGRES.getJdbcUrl());
            singleConnectionPool.setUsername(POSTGRES.getUsername());
            singleConnectionPool.setPassword(POSTGRES.getPassword());
            singleConnectionPool.setMaximumPoolSize(1);
            singleConnectionPool.setMinimumIdle(0);
            singleConnectionPool.setConnectionTimeout(1_000);
            singleConnectionPool.setPoolName("account-export-single-connection");
            JdbcTemplate singleConnectionJdbcTemplate =
                    new JdbcTemplate(singleConnectionPool);
            singleConnectionJdbcTemplate.setQueryTimeout(5);
            AccountDeletionRegistry deletionRegistry =
                    new AccountDeletionRegistry(singleConnectionJdbcTemplate);
            AccountExportSnapshotTransaction exportTransaction =
                    new AccountExportSnapshotTransaction(
                            singleConnectionJdbcTemplate,
                            deletionRegistry
                    );

            Map<String, Object> snapshot = exportTransaction.read(
                    userId,
                    (jdbc, exportedAt) -> Map.of(
                            "users",
                            jdbc.queryForObject(
                                    "SELECT count(*) FROM app_user WHERE user_id = ?",
                                    Integer.class,
                                    userId
                            ),
                            "isolation",
                            jdbc.queryForObject(
                                    "SHOW transaction_isolation",
                                    String.class
                            ),
                            "readOnly",
                            jdbc.queryForObject(
                                    "SHOW transaction_read_only",
                                    String.class
                            ),
                            "exportedAt",
                            exportedAt
                    )
            );

            assertEquals(1, snapshot.get("users"));
            assertEquals("repeatable read", snapshot.get("isolation"));
            assertEquals("on", snapshot.get("readOnly"));
            assertInstanceOf(Instant.class, snapshot.get("exportedAt"));
            assertEquals(
                    "COMPLETED",
                    service.requestAccountDeletion(
                            userId,
                            "single-connection-export-deletion",
                            "DELETE"
                    ).status()
            );
        }

        assertEquals(0, rowCount("app_user"));
        assertEquals(1, rowCount("account_deletion_receipt"));
    }

    @Test
    void shouldSerializeAccountExportWithDeletionForSameSubject() throws Exception {
        String userId = "export-deletion-race-user";
        seedAccount(userId);
        ExecutorService executor = Executors.newFixedThreadPool(2);
        Future<Map<String, Object>> export = null;
        Future<AccountDeletionReceipt> deletion = null;

        try (Connection blocker = dataSource.getConnection()) {
            try {
                blocker.setAutoCommit(false);
                try (Statement lock = blocker.createStatement()) {
                    lock.execute(
                            "LOCK TABLE first_journey_milestone IN ACCESS EXCLUSIVE MODE"
                    );
                }

                export = executor.submit(() -> service.exportAccount(userId));
                awaitAccountExportMilestoneReadBlock();

                Future<AccountDeletionReceipt> deletionTask = executor.submit(
                        () -> service.requestAccountDeletion(
                                userId,
                                "export-race-deletion",
                                "DELETE"
                        )
                );
                deletion = deletionTask;
                awaitBlockedQuery("pg_advisory_xact_lock");
                assertThrows(
                        TimeoutException.class,
                        () -> deletionTask.get(250, TimeUnit.MILLISECONDS)
                );

                blocker.commit();
                Map<String, Object> snapshot = export.get(5, TimeUnit.SECONDS);
                assertEquals(1, ((List<?>) snapshot.get("user")).size());
                assertEquals(
                        1,
                        ((List<?>) snapshot.get("firstJourneyMilestones")).size()
                );
                assertEquals(
                        "COMPLETED",
                        deletionTask.get(5, TimeUnit.SECONDS).status()
                );
            } finally {
                try {
                    blocker.rollback();
                } finally {
                    if (export != null && !export.isDone()) {
                        export.cancel(true);
                    }
                    if (deletion != null && !deletion.isDone()) {
                        deletion.cancel(true);
                    }
                    executor.shutdownNow();
                    executor.awaitTermination(5, TimeUnit.SECONDS);
                }
            }
        }

        assertEquals(0, rowCount("app_user"));
        assertEquals(0, rowCount("first_journey_milestone"));
        assertEquals(1, rowCount("account_deletion_receipt"));
        assertThrows(
                AccountDeletedException.class,
                () -> service.exportAccount(userId)
        );
    }

    @Test
    void shouldRejectExportAfterWaitingForConcurrentDeletion() throws Exception {
        String userId = "deletion-export-race-user";
        seedAccount(userId);
        ExecutorService executor = Executors.newFixedThreadPool(2);
        Future<AccountDeletionReceipt> deletion = null;
        Future<Map<String, Object>> export = null;

        try (Connection blocker = dataSource.getConnection()) {
            try {
                blocker.setAutoCommit(false);
                try (Statement lock = blocker.createStatement()) {
                    lock.execute("LOCK TABLE app_user IN ACCESS EXCLUSIVE MODE");
                }

                deletion = executor.submit(() -> service.requestAccountDeletion(
                        userId,
                        "deletion-before-export",
                        "DELETE"
                ));
                awaitBlockedQuery("DELETE FROM app_user");

                Future<Map<String, Object>> exportTask = executor.submit(
                        () -> service.exportAccount(userId)
                );
                export = exportTask;
                awaitBlockedQuery("pg_advisory_lock");
                assertThrows(
                        TimeoutException.class,
                        () -> exportTask.get(250, TimeUnit.MILLISECONDS)
                );

                blocker.commit();
                assertEquals(
                        "COMPLETED",
                        deletion.get(5, TimeUnit.SECONDS).status()
                );
                ExecutionException error = assertThrows(
                        ExecutionException.class,
                        () -> exportTask.get(5, TimeUnit.SECONDS)
                );
                assertInstanceOf(AccountDeletedException.class, error.getCause());
            } finally {
                try {
                    blocker.rollback();
                } finally {
                    if (deletion != null && !deletion.isDone()) {
                        deletion.cancel(true);
                    }
                    if (export != null && !export.isDone()) {
                        export.cancel(true);
                    }
                    executor.shutdownNow();
                    executor.awaitTermination(5, TimeUnit.SECONDS);
                }
            }
        }

        assertEquals(0, rowCount("app_user"));
        assertEquals(1, rowCount("account_deletion_receipt"));
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

    @Test
    void shouldTimestampTelemetryAfterWaitingForAccountLock() throws Exception {
        String userId = "telemetry-lock-time-user";
        Instant lockReleaseTime = Instant.parse("2026-08-06T00:00:30Z");
        clock.set(lockReleaseTime.minusSeconds(60));
        ExecutorService executor = Executors.newSingleThreadExecutor();

        try (Connection blocker = dataSource.getConnection()) {
            blocker.setAutoCommit(false);
            try (PreparedStatement lock = blocker.prepareStatement("""
                    SELECT pg_advisory_xact_lock(hashtextextended(?, 97))
                    """)) {
                lock.setString(1, userId.length() + ":" + userId);
                lock.execute();
            }

            Future<?> pending = executor.submit(() -> service.recordEvent(
                    userId,
                    "retention_boundary",
                    null,
                    Map.of()
            ));
            awaitBlockedQuery("pg_advisory_xact_lock");
            clock.set(lockReleaseTime);
            blocker.commit();
            pending.get(5, TimeUnit.SECONDS);
        } finally {
            executor.shutdownNow();
            executor.awaitTermination(5, TimeUnit.SECONDS);
        }

        assertEquals(lockReleaseTime, timestamp("""
                SELECT received_at
                FROM platform_event
                WHERE user_id = ?
                  AND event_name = 'retention_boundary'
                """, userId));
        assertEquals(lockReleaseTime, timestamp("""
                SELECT occurred_at
                FROM platform_event
                WHERE user_id = ?
                  AND event_name = 'retention_boundary'
                """, userId));
        assertEquals(lockReleaseTime, timestamp("""
                SELECT created_at
                FROM app_user
                WHERE user_id = ?
                """, userId));
    }

    @Test
    void shouldTimestampSquadJoinAfterWaitingForSquadLock() throws Exception {
        String ownerId = "squad-time-owner";
        String memberId = "squad-time-member";
        Instant lockReleaseTime = NOW.plusSeconds(30);
        platformService.execute(ownerId, new PlatformCommandRequest(
                "CREATE_SQUAD",
                "create-squad-time-boundary",
                Map.of("name", "Serialized squad")
        ));
        String squadId = jdbcTemplate.queryForObject("""
                SELECT squad_id::text
                FROM roadmap_squad
                WHERE owner_user_id = ?
                """, String.class, ownerId);
        clock.set(lockReleaseTime.minusSeconds(60));
        PlatformCommandRequest request = new PlatformCommandRequest(
                "JOIN_SQUAD",
                "join-squad-after-lock",
                Map.of("squadId", squadId)
        );
        ExecutorService executor = Executors.newSingleThreadExecutor();
        Future<PlatformCommandResponse> pending = null;

        try (Connection blocker = dataSource.getConnection()) {
            try {
                blocker.setAutoCommit(false);
                try (PreparedStatement lock = blocker.prepareStatement("""
                        SELECT pg_advisory_xact_lock(
                            hashtextextended(CAST(? AS uuid)::text, 61)
                        )
                        """)) {
                    lock.setString(1, squadId);
                    lock.execute();
                }

                pending = executor.submit(() -> platformService.execute(
                        memberId,
                        request
                ));
                awaitBlockedQuery("squad-membership-serialization");
                clock.set(lockReleaseTime);
                blocker.commit();

                PlatformCommandResponse response = pending.get(5, TimeUnit.SECONDS);
                assertEquals(lockReleaseTime, response.serverTime());
                assertEquals(lockReleaseTime, timestamp("""
                        SELECT joined_at
                        FROM roadmap_squad_member
                        WHERE squad_id = ?::uuid
                          AND user_id = ?
                        """, squadId, memberId));
                assertEquals(lockReleaseTime, timestamp("""
                        SELECT updated_at
                        FROM roadmap_user_state
                        WHERE user_id = ?
                        """, memberId));
                assertEquals(lockReleaseTime, timestamp("""
                        SELECT created_at
                        FROM processed_roadmap_command
                        WHERE user_id = ?
                          AND command_type = 'JOIN_SQUAD'
                          AND idempotency_key = 'join-squad-after-lock'
                        """, memberId));
                assertEquals(lockReleaseTime, timestamp("""
                        SELECT occurred_at
                        FROM platform_event
                        WHERE user_id = ?
                          AND event_name = 'platform_command_completed'
                        """, memberId));
                clock.set(lockReleaseTime.plusSeconds(60));
                assertEquals(response, platformService.execute(memberId, request));
            } finally {
                try {
                    blocker.rollback();
                } finally {
                    if (pending != null && !pending.isDone()) {
                        pending.cancel(true);
                    }
                    executor.shutdownNow();
                    executor.awaitTermination(5, TimeUnit.SECONDS);
                }
            }
        }
    }

    @Test
    void shouldSerializeExpeditionAdvanceWithDeletionForSameSubject() throws Exception {
        String userId = "expedition-race-user";
        seedAccount(userId);
        seedEnergyWallet(userId, 100);

        ExecutorService executor = Executors.newFixedThreadPool(2);
        Future<ExpeditionAdvanceResult> advance = null;
        Future<AccountDeletionReceipt> deletion = null;
        try (Connection blocker = dataSource.getConnection()) {
            try {
                blocker.setAutoCommit(false);
                try (Statement lock = blocker.createStatement()) {
                    lock.execute(
                            "LOCK TABLE expedition_progress IN ACCESS EXCLUSIVE MODE"
                    );
                }

                advance = executor.submit(
                        () -> expeditionAdvanceService.advance(new ExpeditionAdvanceCommand(
                                userId,
                                StarterExpeditionContent.EXPEDITION_ID,
                                10,
                                "expedition-race-advance"
                        ))
                );
                awaitBlockedQuery("FROM expedition_progress");

                Future<AccountDeletionReceipt> deletionTask = executor.submit(
                        () -> service.requestAccountDeletion(
                                userId,
                                "expedition-race-deletion",
                                "DELETE"
                        )
                );
                deletion = deletionTask;
                awaitBlockedQuery("pg_advisory_xact_lock");

                assertThrows(
                        TimeoutException.class,
                        () -> deletionTask.get(250, TimeUnit.MILLISECONDS)
                );
                blocker.commit();

                assertEquals(10, advance.get(5, TimeUnit.SECONDS).progressAfter());
                assertEquals(
                        "COMPLETED",
                        deletionTask.get(5, TimeUnit.SECONDS).status()
                );
            } finally {
                try {
                    blocker.rollback();
                } finally {
                    if (advance != null && !advance.isDone()) {
                        advance.cancel(true);
                    }
                    if (deletion != null && !deletion.isDone()) {
                        deletion.cancel(true);
                    }
                    executor.shutdownNow();
                    executor.awaitTermination(5, TimeUnit.SECONDS);
                }
            }
        }

        assertEquals(0, rowCount("app_user"));
        assertEquals(0, rowCount("expedition_progress"));
        assertEquals(0, rowCount("processed_expedition_advance"));
        assertEquals(0, rowCount("economy_wallet"));
        assertEquals(1, rowCount("account_deletion_receipt"));
        assertThrows(
                AccountDeletedException.class,
                () -> expeditionAdvanceService.advance(new ExpeditionAdvanceCommand(
                        userId,
                        StarterExpeditionContent.EXPEDITION_ID,
                        1,
                        "stale-expedition-advance"
                ))
        );
    }

    @Test
    void shouldRejectEventAcknowledgementForDeletedSubject() {
        String userId = "deleted-ack-user";
        seedAccount(userId);
        service.requestAccountDeletion(
                userId,
                "deleted-ack-request",
                "DELETE"
        );

        assertThrows(
                AccountDeletedException.class,
                () -> acknowledgementService.acknowledge(
                        userId,
                        UUID.fromString("10000000-0000-0000-0000-000000000001")
                )
        );
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
        jdbcTemplate.update("""
                INSERT INTO platform_cosmetic_slot_state (
                    user_id, slot, cosmetic_id, version,
                    equipped_at, updated_at
                ) VALUES (?, 'PILOT', 'pilot-scarf', 1, ?, ?)
                """, userId, timestamp, timestamp);
    }

    private void seedEnergyWallet(String userId, long balance) {
        Timestamp timestamp = Timestamp.from(NOW);
        jdbcTemplate.update("""
                INSERT INTO economy_wallet (
                    user_id, currency_code, balance, version,
                    created_at, updated_at
                ) VALUES (?, 'ENERGY', ?, 1, ?, ?)
                """, userId, balance, timestamp, timestamp);
    }

    private int rowCount(String table) {
        Integer count = jdbcTemplate.queryForObject(
                "SELECT count(*) FROM " + table,
                Integer.class
        );
        return count == null ? 0 : count;
    }

    private Instant timestamp(String sql, Object... arguments) {
        return jdbcTemplate.queryForObject(
                sql,
                (resultSet, rowNumber) -> resultSet.getTimestamp(1).toInstant(),
                arguments
        );
    }

    private Instant databaseTime() {
        Timestamp timestamp = jdbcTemplate.queryForObject(
                "SELECT statement_timestamp()",
                Timestamp.class
        );
        if (timestamp == null) {
            throw new IllegalStateException("Database clock returned no timestamp");
        }
        return timestamp.toInstant();
    }

    private void assertSnapshotBoundary(
            Instant earliest,
            Instant exportedAt,
            Instant latest
    ) {
        assertFalse(exportedAt.isBefore(earliest));
        assertFalse(exportedAt.isAfter(latest));
    }

    private void awaitAccountExportMilestoneReadBlock() throws Exception {
        awaitBlockedQuery("FROM first_journey_milestone");
    }

    private void awaitBlockedQuery(String queryFragment) throws Exception {
        long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(5);
        while (System.nanoTime() < deadline) {
            Integer waiting = jdbcTemplate.queryForObject("""
                    SELECT count(*)
                    FROM pg_stat_activity
                    WHERE datname = current_database()
                      AND wait_event_type = 'Lock'
                      AND query LIKE ?
                    """, Integer.class, "%" + queryFragment + "%");
            if (waiting != null && waiting > 0) {
                return;
            }
            Thread.sleep(25);
        }
        throw new IllegalStateException(
                "Expected query did not reach the blocked state: " + queryFragment
        );
    }

    @TestConfiguration(proxyBeanMethods = false)
    static class BlockingPushConfiguration {

        @Bean
        @Primary
        BlockingPushDeliveryProvider blockingPushDeliveryProvider() {
            return new BlockingPushDeliveryProvider();
        }

        @Bean
        @Primary
        MutableClock mutableClock() {
            return new MutableClock(NOW);
        }
    }

    static final class MutableClock extends Clock {
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
