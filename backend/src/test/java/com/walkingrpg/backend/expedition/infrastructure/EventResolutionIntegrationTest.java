package com.walkingrpg.backend.expedition.infrastructure;

import com.walkingrpg.backend.testsupport.PostgresTestContainer;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.function.Supplier;

import javax.sql.DataSource;

import com.walkingrpg.backend.activity.application.ActivitySyncService;
import com.walkingrpg.backend.activity.domain.ActivitySyncCommand;
import com.walkingrpg.backend.expedition.application.EventChoicePetUnavailableException;
import com.walkingrpg.backend.expedition.application.EventChoiceSkillUnavailableException;
import com.walkingrpg.backend.expedition.application.EventResolutionIdempotencyConflictException;
import com.walkingrpg.backend.expedition.application.EventResolutionService;
import com.walkingrpg.backend.expedition.application.EventResultAcknowledgementService;
import com.walkingrpg.backend.expedition.application.ExpeditionAdvanceService;
import com.walkingrpg.backend.expedition.application.PendingEventResultException;
import com.walkingrpg.backend.expedition.application.StarterExpeditionContent;
import com.walkingrpg.backend.expedition.domain.EventIdempotencyScope;
import com.walkingrpg.backend.expedition.domain.EventResolutionCommand;
import com.walkingrpg.backend.expedition.domain.EventResolutionResult;
import com.walkingrpg.backend.expedition.domain.EventResultAcknowledgementResult;
import com.walkingrpg.backend.expedition.domain.ExpeditionAdvanceCommand;
import com.walkingrpg.backend.expedition.domain.ExpeditionAdvanceResult;
import com.walkingrpg.backend.expedition.domain.ExpeditionProgressStatus;
import com.walkingrpg.backend.expedition.domain.ProcessedEventResolution;
import com.walkingrpg.backend.home.api.HomeSnapshotResponse;
import com.walkingrpg.backend.home.application.HomeService;
import com.walkingrpg.backend.home.domain.HomeQuery;
import com.walkingrpg.backend.inventory.application.InventoryService;
import com.walkingrpg.backend.inventory.application.StarterInventoryContent;
import com.walkingrpg.backend.platform.api.PlatformCommandRequest;
import com.walkingrpg.backend.platform.application.PlatformService;
import com.walkingrpg.backend.platform.domain.PlatformSkillIds;
import com.walkingrpg.backend.progression.application.ProgressionService;
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
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

@SpringBootTest
@ActiveProfiles("test")
@Testcontainers
class EventResolutionIntegrationTest {

    private static final LocalDate LOCAL_DATE = LocalDate.of(2026, 7, 26);
    private static final Instant NOW = Instant.parse("2026-07-26T06:00:00Z");

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
    private ActivitySyncService activitySyncService;

    @Autowired
    private ExpeditionAdvanceService expeditionAdvanceService;

    @Autowired
    private EventResolutionService eventResolutionService;

    @Autowired
    private ExpeditionRepository expeditionRepository;

    @Autowired
    private EventResolutionRepository eventResolutionRepository;

    @Autowired
    private ProgressionService progressionService;

    @Autowired
    private PlatformService platformService;

    @Autowired
    private InventoryService inventoryService;

    @Autowired
    private StarterExpeditionContent content;

    @Autowired
    private HomeService homeService;

    @Autowired
    private EventResultAcknowledgementService acknowledgementService;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private DataSource dataSource;

    @Autowired
    private PlatformTransactionManager transactionManager;

    @BeforeEach
    void cleanDatabase() {
        jdbcTemplate.update("DELETE FROM inventory_ledger");
        jdbcTemplate.update("DELETE FROM inventory_stack");
        jdbcTemplate.update("DELETE FROM processed_event_resolution");
        jdbcTemplate.update("DELETE FROM processed_expedition_advance");
        jdbcTemplate.update("DELETE FROM pilot_progress");
        jdbcTemplate.update("DELETE FROM pet_progress");
        jdbcTemplate.update("DELETE FROM expedition_progress");
        jdbcTemplate.update("DELETE FROM processed_activity_sync");
        jdbcTemplate.update("DELETE FROM economy_ledger");
        jdbcTemplate.update("DELETE FROM activity_sync_state");
        jdbcTemplate.update("DELETE FROM economy_wallet");
        jdbcTemplate.update("DELETE FROM app_device");
        jdbcTemplate.update("DELETE FROM app_user");
        jdbcTemplate.update(
                "UPDATE content_release SET is_active = false WHERE is_active"
        );
        jdbcTemplate.update("""
                UPDATE content_release
                SET is_active = true,
                    activated_at = COALESCE(activated_at, now())
                WHERE content_version = 'chapter-1-v1'
                """);
    }

    @Test
    void shouldResolveSecondNodePersistMaterialAndContinueChapter() {
        prepareFirstEvent("event-user");

        EventResolutionResult firstEvent = eventResolutionService.resolve(command(
                "event-user",
                StarterExpeditionContent.FIRST_EVENT_ID,
                "analyze-signal",
                "resolve-first"
        ));
        assertEquals(ExpeditionProgressStatus.IN_PROGRESS, firstEvent.expeditionStatus());
        assertNull(firstEvent.material());
        assertEquals(StarterExpeditionContent.SECOND_NODE_ID, currentNodeId());
        acknowledgementService.acknowledge(
                "event-user",
                firstEvent.receiptId()
        );

        expeditionAdvanceService.advance(new ExpeditionAdvanceCommand(
                "event-user",
                StarterExpeditionContent.EXPEDITION_ID,
                45,
                "advance-second"
        ));
        EventResolutionCommand secondCommand = command(
                "event-user",
                StarterExpeditionContent.SECOND_EVENT_ID,
                "stabilize-core",
                "resolve-second"
        );
        EventResolutionResult secondEvent = eventResolutionService.resolve(secondCommand);

        EventResolutionService restarted = new EventResolutionService(
                expeditionRepository,
                eventResolutionRepository,
                progressionService,
                inventoryService,
                content,
                Clock.fixed(NOW.plusSeconds(300), ZoneOffset.UTC)
        );
        TransactionTemplate transaction = new TransactionTemplate(transactionManager);
        EventResolutionResult replayed = transaction.execute(
                status -> restarted.resolve(secondCommand)
        );

        assertEquals(secondEvent, replayed);
        assertEquals(ExpeditionProgressStatus.IN_PROGRESS, secondEvent.expeditionStatus());
        assertEquals("lumen-shard", secondEvent.material().itemId());
        assertEquals(2, secondEvent.material().quantityGained());
        assertEquals(2, secondEvent.material().quantityAfter());
        assertEquals(90, pilotExperience());
        assertEquals(23, petBond());
        assertEquals(25, walletBalance());
        assertEquals(2, rowCount("processed_event_resolution"));
        assertEquals(2, rowCount("processed_expedition_advance"));
        assertEquals(1, rowCount("pilot_progress"));
        assertEquals(1, rowCount("pet_progress"));
        assertEquals(1, rowCount("inventory_stack"));
        assertEquals(1, rowCount("inventory_ledger"));
        assertEquals(1, milestoneCount("event-user", "FIRST_EVENT_RESOLVED"));
        assertEquals(
                StarterExpeditionContent.FIRST_EVENT_ID,
                jdbcTemplate.queryForObject("""
                        SELECT attributes ->> 'eventId'
                        FROM first_journey_milestone
                        WHERE user_id = 'event-user'
                          AND milestone = 'FIRST_EVENT_RESOLVED'
                        """, String.class)
        );
        assertEquals(2L, inventoryQuantity("lumen-shard"));
        assertEquals("IN_PROGRESS", expeditionStatus());

        HomeSnapshotResponse home = homeService.getSnapshot(
                new HomeQuery("event-user", LOCAL_DATE)
        );
        assertEquals(
                StarterExpeditionContent.LEGACY_CONTENT_VERSION,
                home.contentVersion()
        );
        assertEquals(90, home.pilot().currentExperience());
        assertEquals(23, home.pet().bond());
        assertEquals("IN_PROGRESS", home.expedition().status());
        assertEquals(StarterExpeditionContent.THIRD_NODE_ID,
                home.expedition().currentNodeId());
        assertNull(home.expedition().unlockedEvent());
        assertNotNull(home.pendingEventResult());
        assertEquals(secondEvent.receiptId(), home.pendingEventResult().receiptId());
        assertEquals(StarterExpeditionContent.SECOND_EVENT_ID,
                home.pendingEventResult().eventId());
        assertEquals(3, home.expedition().routeTrail().size());
        assertEquals(StarterExpeditionContent.FIRST_NODE_ID,
                home.expedition().routeTrail().get(0).nodeId());
        assertEquals("VISITED", home.expedition().routeTrail().get(0).state());
        assertEquals(StarterExpeditionContent.SECOND_NODE_ID,
                home.expedition().routeTrail().get(1).nodeId());
        assertEquals("VISITED", home.expedition().routeTrail().get(1).state());
        assertEquals(StarterExpeditionContent.THIRD_NODE_ID,
                home.expedition().routeTrail().get(2).nodeId());
        assertEquals("CURRENT", home.expedition().routeTrail().get(2).state());
        assertEquals(2, home.expedition().decisionLog().size());
        assertEquals(firstEvent.eventId(),
                home.expedition().decisionLog().getFirst().eventId());
        assertEquals(firstEvent.choiceTitle(),
                home.expedition().decisionLog().getFirst().choiceTitle());
        assertEquals(secondEvent.eventTitle(),
                home.expedition().decisionLog().getLast().eventTitle());
        assertEquals(secondEvent.outcomeTitle(),
                home.expedition().decisionLog().getLast().outcomeTitle());
        assertEquals(secondEvent.outcomeSummary(),
                home.expedition().decisionLog().getLast().outcomeSummary());
        assertEquals(secondEvent.serverTime(),
                home.expedition().decisionLog().getLast().resolvedAt());
        assertEquals("Пепельная орбита",
                home.pendingEventResult().nextNode().name());
        assertEquals(1, home.inventory().size());
        assertEquals("lumen-shard", home.inventory().getFirst().itemId());
        assertEquals(2, home.inventory().getFirst().quantity());

        var acknowledgement = acknowledgementService.acknowledge(
                "event-user",
                secondEvent.receiptId()
        );
        var replayedAcknowledgement = acknowledgementService.acknowledge(
                "event-user",
                secondEvent.receiptId()
        );
        assertEquals(acknowledgement.acknowledgedAt(),
                replayedAcknowledgement.acknowledgedAt());

        HomeSnapshotResponse acknowledgedHome = homeService.getSnapshot(
                new HomeQuery("event-user", LOCAL_DATE)
        );
        assertNull(acknowledgedHome.pendingEventResult());
        assertEquals(StarterExpeditionContent.THIRD_NODE_ID,
                acknowledgedHome.expedition().currentNodeId());
        assertEquals(90, acknowledgedHome.pilot().currentExperience());
        assertEquals(23, acknowledgedHome.pet().bond());
        assertEquals(2, acknowledgedHome.inventory().getFirst().quantity());

        assertThrows(
                EventResolutionIdempotencyConflictException.class,
                () -> eventResolutionService.resolve(command(
                        "event-user",
                        StarterExpeditionContent.SECOND_EVENT_ID,
                        "follow-echo",
                        "resolve-second"
                ))
        );

        expeditionRepository.saveJourneyNumber(
                "event-user",
                StarterExpeditionContent.EXPEDITION_ID,
                2,
                NOW
        );
        jdbcTemplate.update("""
                UPDATE expedition_progress
                SET current_node_id = ?,
                    progress_energy = 0,
                    required_energy = 30,
                    status = 'IN_PROGRESS',
                    unlocked_event_id = NULL,
                    version = version + 1,
                    updated_at = now()
                WHERE user_id = ?
                  AND expedition_id = ?
                """,
                StarterExpeditionContent.FIRST_NODE_ID,
                "event-user",
                StarterExpeditionContent.EXPEDITION_ID);

        HomeSnapshotResponse nextJourney = homeService.getSnapshot(
                new HomeQuery("event-user", LOCAL_DATE)
        );
        assertEquals(2, nextJourney.expedition().journeyNumber());
        assertEquals(1, nextJourney.expedition().routeTrail().size());
        assertEquals(StarterExpeditionContent.FIRST_NODE_ID,
                nextJourney.expedition().routeTrail().getFirst().nodeId());
        assertEquals("CURRENT",
                nextJourney.expedition().routeTrail().getFirst().state());
        assertEquals(0, nextJourney.expedition().decisionLog().size());
    }

    @Test
    void shouldRequireAcknowledgementBeforeAdvancingToAnotherResult() {
        String userId = "pending-result-user";
        prepareFirstEvent(userId);
        EventResolutionResult firstEvent = eventResolutionService.resolve(command(
                userId,
                StarterExpeditionContent.FIRST_EVENT_ID,
                "analyze-signal",
                "pending-first"
        ));
        ExpeditionAdvanceResult replayedInitialAdvance =
                expeditionAdvanceService.advance(new ExpeditionAdvanceCommand(
                        userId,
                        StarterExpeditionContent.EXPEDITION_ID,
                        30,
                        "advance-first-" + userId
                ));
        long balanceBeforeAdvance = walletBalance();

        assertEquals(ExpeditionProgressStatus.EVENT_READY,
                replayedInitialAdvance.status());
        assertEquals(30, replayedInitialAdvance.progressAfter());
        PendingEventResultException conflict = assertThrows(
                PendingEventResultException.class,
                () -> expeditionAdvanceService.advance(
                        new ExpeditionAdvanceCommand(
                                userId,
                                StarterExpeditionContent.EXPEDITION_ID,
                                1,
                                "advance-before-ack"
                        )
                )
        );

        assertEquals(firstEvent.receiptId(), conflict.receiptId());
        assertEquals(firstEvent.eventId(), conflict.eventId());
        assertEquals(balanceBeforeAdvance, walletBalance());
        assertEquals(1, rowCount("processed_expedition_advance"));

        acknowledgementService.acknowledge(userId, firstEvent.receiptId());
        ExpeditionAdvanceResult continued = expeditionAdvanceService.advance(
                new ExpeditionAdvanceCommand(
                        userId,
                        StarterExpeditionContent.EXPEDITION_ID,
                        1,
                        "advance-after-ack"
                )
        );
        assertEquals(1, continued.progressAfter());
    }

    @Test
    void shouldKeepAcknowledgementTimeMonotonicAfterClockRollback() {
        String userId = "clock-rollback-user";
        prepareFirstEvent(userId);
        EventResolutionResult event = eventResolutionService.resolve(command(
                userId,
                StarterExpeditionContent.FIRST_EVENT_ID,
                "analyze-signal",
                "clock-rollback-event"
        ));
        EventResultAcknowledgementService rolledBackClockService =
                new EventResultAcknowledgementService(
                        eventResolutionRepository,
                        Clock.fixed(NOW, ZoneOffset.UTC)
                );
        TransactionTemplate transaction = new TransactionTemplate(transactionManager);

        var acknowledged = transaction.execute(status ->
                rolledBackClockService.acknowledge(userId, event.receiptId())
        );

        assertNotNull(acknowledged);
        assertEquals(event.serverTime(), acknowledged.acknowledgedAt());
        assertEquals(event.serverTime(), acknowledged.serverTime());
        assertNull(homeService.getSnapshot(
                new HomeQuery(userId, LOCAL_DATE)
        ).pendingEventResult());
    }

    @Test
    void shouldTimestampAcknowledgementAfterWaitingForAccountLock()
            throws Exception {
        String userId = "ack-lock-time-user";
        prepareFirstEvent(userId);
        EventResolutionResult event = eventResolutionService.resolve(command(
                userId,
                StarterExpeditionContent.FIRST_EVENT_ID,
                "analyze-signal",
                "ack-lock-time-event"
        ));
        Instant lockReleaseTime = event.serverTime().plusSeconds(30);

        MutableClock clock = new MutableClock(lockReleaseTime.minusSeconds(30));
        EventResultAcknowledgementService orderedService =
                new EventResultAcknowledgementService(
                        eventResolutionRepository,
                        clock
                );
        TransactionTemplate transaction = new TransactionTemplate(transactionManager);
        ExecutorService executor = Executors.newSingleThreadExecutor();

        EventResultAcknowledgementResult result;
        try {
            try (Connection blocker = dataSource.getConnection()) {
                blocker.setAutoCommit(false);
                try (PreparedStatement lock = blocker.prepareStatement("""
                        SELECT pg_advisory_xact_lock(hashtextextended(?, 97))
                        """)) {
                    lock.setString(1, accountLockKey(userId));
                    lock.execute();
                }

                Future<EventResultAcknowledgementResult> pending = executor.submit(() ->
                        transaction.execute(status ->
                                orderedService.acknowledge(
                                        userId,
                                        event.receiptId()
                                )
                        )
                );
                awaitAdvisoryLockWait();
                clock.set(lockReleaseTime);
                blocker.commit();
                result = pending.get(10, TimeUnit.SECONDS);
            }
        } finally {
            executor.shutdownNow();
        }

        assertEquals(lockReleaseTime, result.acknowledgedAt());
        assertEquals(lockReleaseTime, result.serverTime());
        assertEquals(lockReleaseTime, timestamp("""
                SELECT acknowledged_at
                FROM processed_event_resolution
                WHERE user_id = ?
                  AND receipt_id = ?
                """, userId, event.receiptId()));
        assertEquals(lockReleaseTime, timestamp("""
                SELECT occurred_at
                FROM first_journey_milestone
                WHERE user_id = ?
                  AND milestone = 'FIRST_EVENT_RESULT_ACKNOWLEDGED'
                """, userId));

        clock.set(lockReleaseTime.plusSeconds(30));
        EventResultAcknowledgementResult replayed = transaction.execute(status ->
                orderedService.acknowledge(userId, event.receiptId())
        );
        assertEquals(result, replayed);
    }

    @Test
    void shouldRecordLegacyAutoAcknowledgementWithoutInventingTiming() {
        String userId = "legacy-auto-ack-user";
        prepareFirstEvent(userId);

        EventResolutionResult event = eventResolutionService.resolve(
                command(
                        userId,
                        StarterExpeditionContent.FIRST_EVENT_ID,
                        "analyze-signal",
                        "legacy-auto-ack-event"
                ),
                false
        );

        assertEquals(false, event.handoffRequired());
        assertEquals(1, milestoneCount(
                userId,
                "FIRST_EVENT_RESULT_ACKNOWLEDGED"
        ));
        assertEquals(event.serverTime(), jdbcTemplate.queryForObject("""
                SELECT occurred_at
                FROM first_journey_milestone
                WHERE user_id = ?
                  AND milestone = 'FIRST_EVENT_RESULT_ACKNOWLEDGED'
                """, Timestamp.class, userId).toInstant());
        assertEquals("BACKFILLED", jdbcTemplate.queryForObject("""
                SELECT source
                FROM first_journey_milestone
                WHERE user_id = ?
                  AND milestone = 'FIRST_EVENT_RESULT_ACKNOWLEDGED'
                """, String.class, userId));
        assertEquals("LEGACY_AUTO_ACK", jdbcTemplate.queryForObject("""
                SELECT attributes ->> 'deliveryMode'
                FROM first_journey_milestone
                WHERE user_id = ?
                  AND milestone = 'FIRST_EVENT_RESULT_ACKNOWLEDGED'
                """, String.class, userId));
    }

    @Test
    void shouldSerializeConcurrentAcknowledgementsAndAvoidReplayUpdate()
            throws Exception {
        String userId = "concurrent-ack-user";
        prepareFirstEvent(userId);
        EventResolutionResult event = eventResolutionService.resolve(command(
                userId,
                StarterExpeditionContent.FIRST_EVENT_ID,
                "analyze-signal",
                "concurrent-ack-event"
        ));
        assertEquals(0, milestoneCount(
                userId,
                "FIRST_EVENT_RESULT_ACKNOWLEDGED"
        ));
        EventResultAcknowledgementService firstService =
                new EventResultAcknowledgementService(
                        eventResolutionRepository,
                        Clock.fixed(
                                event.serverTime().plusSeconds(1),
                                ZoneOffset.UTC
                        )
                );
        EventResultAcknowledgementService secondService =
                new EventResultAcknowledgementService(
                        eventResolutionRepository,
                        Clock.fixed(
                                event.serverTime().plusSeconds(2),
                                ZoneOffset.UTC
                        )
                );

        ExecutorService executor = Executors.newFixedThreadPool(2);
        CountDownLatch ready = new CountDownLatch(2);
        CountDownLatch start = new CountDownLatch(1);
        try {
            Future<EventResultAcknowledgementResult> first = executor.submit(() ->
                    new TransactionTemplate(transactionManager).execute(status -> {
                        ready.countDown();
                        awaitLatch(start, "start concurrent acknowledgement");
                        return firstService.acknowledge(userId, event.receiptId());
                    })
            );
            Future<EventResultAcknowledgementResult> second = executor.submit(() ->
                    new TransactionTemplate(transactionManager).execute(status -> {
                        ready.countDown();
                        awaitLatch(start, "start concurrent acknowledgement");
                        return secondService.acknowledge(userId, event.receiptId());
                    })
            );

            assertTrue(ready.await(10, TimeUnit.SECONDS));
            start.countDown();

            EventResultAcknowledgementResult firstResult =
                    first.get(10, TimeUnit.SECONDS);
            EventResultAcknowledgementResult secondResult =
                    second.get(10, TimeUnit.SECONDS);
            assertNotNull(firstResult);
            assertNotNull(secondResult);
            assertEquals(firstResult, secondResult);
            assertEquals(1, milestoneCount(
                    userId,
                    "FIRST_EVENT_RESULT_ACKNOWLEDGED"
            ));
            assertEquals(firstResult.acknowledgedAt(),
                    jdbcTemplate.queryForObject("""
                            SELECT occurred_at
                            FROM first_journey_milestone
                            WHERE user_id = ?
                              AND milestone =
                                  'FIRST_EVENT_RESULT_ACKNOWLEDGED'
                            """, Timestamp.class, userId).toInstant());
            assertEquals("AUTHORITATIVE", jdbcTemplate.queryForObject("""
                    SELECT source
                    FROM first_journey_milestone
                    WHERE user_id = ?
                      AND milestone = 'FIRST_EVENT_RESULT_ACKNOWLEDGED'
                    """, String.class, userId));
            assertEquals("DURABLE_ACK", jdbcTemplate.queryForObject("""
                    SELECT attributes ->> 'deliveryMode'
                    FROM first_journey_milestone
                    WHERE user_id = ?
                      AND milestone = 'FIRST_EVENT_RESULT_ACKNOWLEDGED'
                    """, String.class, userId));

            String rowVersionBeforeReplay = jdbcTemplate.queryForObject("""
                    SELECT xmin::text
                    FROM processed_event_resolution
                    WHERE user_id = ?
                      AND receipt_id = ?
                    """, String.class, userId, event.receiptId());
            EventResultAcknowledgementResult replayed =
                    acknowledgementService.acknowledge(userId, event.receiptId());
            String rowVersionAfterReplay = jdbcTemplate.queryForObject("""
                    SELECT xmin::text
                    FROM processed_event_resolution
                    WHERE user_id = ?
                      AND receipt_id = ?
                    """, String.class, userId, event.receiptId());

            assertEquals(firstResult, replayed);
            assertEquals(rowVersionBeforeReplay, rowVersionAfterReplay);
            assertEquals(1, milestoneCount(
                    userId,
                    "FIRST_EVENT_RESULT_ACKNOWLEDGED"
            ));
            assertThrows(DataIntegrityViolationException.class, () ->
                    jdbcTemplate.update("""
                            UPDATE processed_event_resolution
                            SET acknowledged_at =
                                acknowledged_at + interval '1 second'
                            WHERE user_id = ?
                              AND receipt_id = ?
                            """, userId, event.receiptId())
            );
            assertThrows(DataIntegrityViolationException.class, () ->
                    jdbcTemplate.update("""
                            UPDATE processed_event_resolution
                            SET handoff_required = false
                            WHERE user_id = ?
                              AND receipt_id = ?
                            """, userId, event.receiptId())
            );
        } finally {
            start.countDown();
            executor.shutdownNow();
        }
    }

    @Test
    void shouldRollbackAcknowledgementMilestoneWithReceiptUpdate() {
        String userId = "rollback-ack-user";
        prepareFirstEvent(userId);
        EventResolutionResult event = eventResolutionService.resolve(command(
                userId,
                StarterExpeditionContent.FIRST_EVENT_ID,
                "analyze-signal",
                "rollback-ack-event"
        ));

        new TransactionTemplate(transactionManager).executeWithoutResult(status -> {
            acknowledgementService.acknowledge(userId, event.receiptId());
            status.setRollbackOnly();
        });

        assertEquals(0, milestoneCount(
                userId,
                "FIRST_EVENT_RESULT_ACKNOWLEDGED"
        ));
        assertNull(jdbcTemplate.queryForObject("""
                SELECT acknowledged_at
                FROM processed_event_resolution
                WHERE user_id = ?
                  AND receipt_id = ?
                """, Timestamp.class, userId, event.receiptId()));
    }

    @Test
    void shouldRollbackSecondEventInventoryProgressionAndExpeditionOnLateFailure() {
        prepareFirstEvent("rollback-event-user");
        EventResolutionResult firstEvent = eventResolutionService.resolve(command(
                "rollback-event-user",
                StarterExpeditionContent.FIRST_EVENT_ID,
                "analyze-signal",
                "rollback-first"
        ));
        acknowledgementService.acknowledge(
                "rollback-event-user",
                firstEvent.receiptId()
        );
        expeditionAdvanceService.advance(new ExpeditionAdvanceCommand(
                "rollback-event-user",
                StarterExpeditionContent.EXPEDITION_ID,
                45,
                "rollback-advance-second"
        ));
        EventResolutionRepository failingRepository = new EventResolutionRepository() {
            @Override
            public Optional<ProcessedEventResolution> findProcessed(
                    EventIdempotencyScope scope
            ) {
                return eventResolutionRepository.findProcessed(scope);
            }

            @Override
            public Optional<ProcessedEventResolution> findPendingResult(
                    String userId,
                    String expeditionId
            ) {
                return eventResolutionRepository.findPendingResult(
                        userId,
                        expeditionId
                );
            }

            @Override
            public void saveProcessed(
                    EventIdempotencyScope scope,
                    ProcessedEventResolution processed
            ) {
                throw new IllegalStateException("forced processed event failure");
            }

            @Override
            public Optional<EventResultAcknowledgementResult> acknowledgeResult(
                    String userId,
                    UUID receiptId,
                    Supplier<Instant> serverTimeSupplier
            ) {
                return eventResolutionRepository.acknowledgeResult(
                        userId,
                        receiptId,
                        serverTimeSupplier
                );
            }
        };
        EventResolutionService failingService = new EventResolutionService(
                expeditionRepository,
                failingRepository,
                progressionService,
                inventoryService,
                content,
                Clock.fixed(NOW, ZoneOffset.UTC)
        );
        TransactionTemplate transaction = new TransactionTemplate(transactionManager);

        assertThrows(
                IllegalStateException.class,
                () -> transaction.executeWithoutResult(status -> failingService.resolve(
                        command(
                                "rollback-event-user",
                                StarterExpeditionContent.SECOND_EVENT_ID,
                                "stabilize-core",
                                "rollback-second"
                        )
                ))
        );

        assertEquals("EVENT_READY", expeditionStatus());
        assertEquals(60, pilotExperience());
        assertEquals(15, petBond());
        assertEquals(0, rowCount("inventory_stack"));
        assertEquals(0, rowCount("inventory_ledger"));
        assertEquals(1, rowCount("processed_event_resolution"));
        assertEquals(25, walletBalance());
        assertEquals(1, milestoneCount(
                "rollback-event-user",
                "FIRST_EVENT_RESOLVED"
        ));
    }

    @Test
    void shouldRewardSelectedPetAndExposeItOnHome() {
        String userId = "selected-pet-user";
        platformService.execute(userId, new PlatformCommandRequest(
                "SELECT_PET",
                "select-moss-first-journey",
                Map.of("petId", "moss-v1")
        ));
        prepareFirstEvent(userId);
        platformService.execute(userId, new PlatformCommandRequest(
                "CLAIM_QUEST",
                "claim-walk-quest-with-moss",
                Map.of("questId", "walk-3000")
        ));

        HomeSnapshotResponse beforeEvent = homeService.getSnapshot(
                new HomeQuery(userId, LOCAL_DATE)
        );
        assertEquals("Мох", beforeEvent.pet().name());
        assertEquals(14, beforeEvent.pet().bond());

        EventResolutionResult result = eventResolutionService.resolve(command(
                userId,
                StarterExpeditionContent.FIRST_EVENT_ID,
                "analyze-signal",
                "resolve-with-moss"
        ));

        assertEquals("moss-v1", result.pet().petId());
        assertEquals("Мох", result.pet().name());
        assertEquals(19, result.pet().bond());
        assertEquals("moss-v1", jdbcTemplate.queryForObject("""
                SELECT pet_id
                FROM pet_progress
                WHERE user_id = ?
                """, String.class, userId));
        assertEquals(0, jdbcTemplate.queryForObject("""
                SELECT count(*)
                FROM pet_progress
                WHERE user_id = ?
                  AND pet_id = 'spark-v1'
                """, Integer.class, userId));

        HomeSnapshotResponse home = homeService.getSnapshot(
                new HomeQuery(userId, LOCAL_DATE)
        );
        assertEquals("Мох", home.pet().name());
        assertEquals("Терра", home.pet().species());
        assertEquals(19, home.pet().bond());
    }

    @Test
    void shouldProjectAndResolveOnlyTheActivePetsUnchartedOutcome() {
        String userId = "pet-guided-verge-user";
        platformService.execute(userId, new PlatformCommandRequest(
                "SELECT_PET",
                "select-moss-at-verge",
                Map.of("petId", "moss-v1")
        ));
        jdbcTemplate.update(
                "UPDATE content_release SET is_active = false WHERE is_active"
        );
        assertEquals(1, jdbcTemplate.update("""
                UPDATE content_release
                SET is_active = true,
                    activated_at = COALESCE(activated_at, now())
                WHERE content_version = 'chapter-1-v10'
                """));
        jdbcTemplate.update("""
                INSERT INTO expedition_progress (
                    user_id, expedition_id, current_node_id,
                    progress_energy, required_energy, status,
                    unlocked_event_id, version, created_at, updated_at
                ) VALUES (?, ?, ?, 70, 70, 'EVENT_READY', ?, 42, now(), now())
                """,
                userId,
                StarterExpeditionContent.EXPEDITION_ID,
                StarterExpeditionContent.UNCHARTED_VERGE_NODE_ID,
                StarterExpeditionContent.UNCHARTED_VERGE_EVENT_ID
        );

        HomeSnapshotResponse home = homeService.getSnapshot(
                new HomeQuery(userId, LOCAL_DATE)
        );

        assertEquals(
                StarterExpeditionContent.PET_GUIDED_UNCHARTED_CONTENT_VERSION,
                home.contentVersion()
        );
        assertEquals(1L, home.expedition().unlockedEvent().choices().stream()
                .filter(choice -> choice.requirement() != null
                        && "ACTIVE_PET".equals(choice.requirement().type()))
                .count());
        assertEquals(
                StarterExpeditionContent.MOSS_UNCHARTED_CHOICE_ID,
                home.expedition().unlockedEvent().choices().stream()
                        .filter(choice -> choice.requirement() != null
                                && "ACTIVE_PET".equals(
                                        choice.requirement().type()
                                ))
                        .findFirst()
                        .orElseThrow()
                        .choiceId()
        );
        assertEquals(2L, home.expedition().unlockedEvent().lockedChoices().stream()
                .filter(choice -> choice.requirement() != null
                        && "ACTIVE_PET".equals(choice.requirement().type()))
                .count());
        assertEquals(
                List.of("rune-v1", "spark-v1"),
                home.expedition().unlockedEvent().lockedChoices().stream()
                        .filter(choice -> choice.requirement() != null
                                && "ACTIVE_PET".equals(
                                        choice.requirement().type()
                                ))
                        .map(choice -> choice.requirement().itemId())
                        .sorted()
                        .toList()
        );

        assertThrows(
                EventChoicePetUnavailableException.class,
                () -> eventResolutionService.resolve(command(
                        userId,
                        StarterExpeditionContent.UNCHARTED_VERGE_EVENT_ID,
                        StarterExpeditionContent.SPARK_UNCHARTED_CHOICE_ID,
                        "reject-spark-with-moss"
                ))
        );
        assertEquals(0, rowCount("processed_event_resolution"));
        assertEquals(0, rowCount("inventory_stack"));
        assertEquals(0, rowCount("pilot_progress"));
        assertEquals(0, rowCount("pet_progress"));

        EventResolutionCommand command = command(
                userId,
                StarterExpeditionContent.UNCHARTED_VERGE_EVENT_ID,
                StarterExpeditionContent.MOSS_UNCHARTED_CHOICE_ID,
                "resolve-moss-at-verge"
        );
        EventResolutionResult result = eventResolutionService.resolve(command);
        EventResolutionResult replayed = eventResolutionService.resolve(command);

        assertEquals(result, replayed);
        assertEquals(ExpeditionProgressStatus.COMPLETED,
                result.expeditionStatus());
        assertEquals("moss-v1", result.pet().petId());
        assertEquals("ash-seed", result.material().itemId());
        assertEquals(3, result.material().quantityGained());
        assertEquals(3L, inventoryQuantity("ash-seed"));
        assertEquals(1, rowCount("processed_event_resolution"));
        assertEquals(1, rowCount("pilot_progress"));
        assertEquals(1, rowCount("pet_progress"));
    }

    @Test
    void shouldGateAdultPetFrontierAndCompleteSanctuary() {
        String userId = "adult-pet-frontier-user";
        platformService.execute(userId, new PlatformCommandRequest(
                "SELECT_PET",
                "select-spark-for-adult-frontier",
                Map.of("petId", "spark-v1")
        ));
        jdbcTemplate.update("""
                UPDATE roadmap_user_state
                SET state_json = jsonb_set(
                    jsonb_set(
                        jsonb_set(
                            state_json,
                            '{pets,spark-v1,level}',
                            '2'::jsonb
                        ),
                        '{pets,spark-v1,bond}',
                        '145'::jsonb
                    ),
                    '{pets,spark-v1,evolutionStage}',
                    '1'::jsonb
                )
                WHERE user_id = ?
                """, userId);
        jdbcTemplate.update(
                "UPDATE content_release SET is_active = false WHERE is_active"
        );
        assertEquals(1, jdbcTemplate.update("""
                UPDATE content_release
                SET is_active = true,
                    activated_at = COALESCE(activated_at, now())
                WHERE content_version = 'chapter-1-v12'
                """));
        jdbcTemplate.update("""
                INSERT INTO expedition_progress (
                    user_id, expedition_id, current_node_id,
                    progress_energy, required_energy, status,
                    unlocked_event_id, version, created_at, updated_at
                ) VALUES (?, ?, ?, 70, 70, 'EVENT_READY', ?, 43, now(), now())
                """,
                userId,
                StarterExpeditionContent.EXPEDITION_ID,
                StarterExpeditionContent.UNCHARTED_VERGE_NODE_ID,
                StarterExpeditionContent.UNCHARTED_VERGE_EVENT_ID
        );

        HomeSnapshotResponse youngHome = homeService.getSnapshot(
                new HomeQuery(userId, LOCAL_DATE)
        );
        var youngAdultChoice = youngHome.expedition().unlockedEvent()
                .lockedChoices().stream()
                .filter(choice -> StarterExpeditionContent
                        .SPARK_ADULT_FRONTIER_CHOICE_ID.equals(
                                choice.choiceId()
                        ))
                .findFirst()
                .orElseThrow();

        assertEquals(
                StarterExpeditionContent.ADULT_PET_FRONTIER_CONTENT_VERSION,
                youngHome.contentVersion()
        );
        assertEquals(2, youngAdultChoice.requirement()
                .minimumEvolutionStage());
        EventChoicePetUnavailableException unavailable = assertThrows(
                EventChoicePetUnavailableException.class,
                () -> eventResolutionService.resolve(command(
                        userId,
                        StarterExpeditionContent.UNCHARTED_VERGE_EVENT_ID,
                        StarterExpeditionContent.SPARK_ADULT_FRONTIER_CHOICE_ID,
                        "reject-young-spark-frontier"
                ))
        );
        assertEquals(2, unavailable.requiredEvolutionStage());
        assertEquals(1, unavailable.actualEvolutionStage());
        assertEquals(0, rowCount("processed_event_resolution"));
        assertEquals(0, rowCount("inventory_stack"));
        assertEquals(0, rowCount("pilot_progress"));
        assertEquals(0, rowCount("pet_progress"));

        jdbcTemplate.update("""
                UPDATE roadmap_user_state
                SET state_json = jsonb_set(
                    jsonb_set(
                        state_json,
                        '{pets,spark-v1,level}',
                        '3'::jsonb
                    ),
                    '{pets,spark-v1,evolutionStage}',
                    '2'::jsonb
                )
                WHERE user_id = ?
                """, userId);

        HomeSnapshotResponse adultHome = homeService.getSnapshot(
                new HomeQuery(userId, LOCAL_DATE)
        );
        assertTrue(adultHome.expedition().unlockedEvent().choices().stream()
                .anyMatch(choice -> StarterExpeditionContent
                        .SPARK_ADULT_FRONTIER_CHOICE_ID.equals(
                                choice.choiceId()
                        )));
        assertEquals(2L, adultHome.expedition().unlockedEvent()
                .lockedChoices().stream()
                .filter(choice -> choice.requirement() != null
                        && choice.requirement().minimumEvolutionStage() == 2)
                .count());

        EventResolutionCommand routeCommand = command(
                userId,
                StarterExpeditionContent.UNCHARTED_VERGE_EVENT_ID,
                StarterExpeditionContent.SPARK_ADULT_FRONTIER_CHOICE_ID,
                "resolve-adult-spark-frontier"
        );
        EventResolutionResult route = eventResolutionService.resolve(
                routeCommand
        );
        EventResolutionResult routeReplay = eventResolutionService.resolve(
                routeCommand
        );

        assertEquals(route, routeReplay);
        assertEquals(ExpeditionProgressStatus.IN_PROGRESS,
                route.expeditionStatus());
        assertEquals(
                StarterExpeditionContent.CONSTELLATION_SANCTUARY_NODE_ID,
                route.nextNode().nodeId()
        );
        assertEquals("spark-v1", route.pet().petId());
        assertEquals(2L, inventoryQuantity("ion-bloom"));
        acknowledgementService.acknowledge(userId, route.receiptId());

        jdbcTemplate.update("""
                UPDATE expedition_progress
                SET progress_energy = required_energy,
                    status = 'EVENT_READY',
                    unlocked_event_id = ?,
                    version = version + 1,
                    updated_at = now()
                WHERE user_id = ?
                  AND expedition_id = ?
                  AND current_node_id = ?
                """,
                StarterExpeditionContent.CONSTELLATION_SANCTUARY_EVENT_ID,
                userId,
                StarterExpeditionContent.EXPEDITION_ID,
                StarterExpeditionContent.CONSTELLATION_SANCTUARY_NODE_ID
        );
        EventResolutionCommand finaleCommand = command(
                userId,
                StarterExpeditionContent.CONSTELLATION_SANCTUARY_EVENT_ID,
                "anchor-constellation-sanctuary",
                "complete-adult-pet-sanctuary"
        );
        EventResolutionResult finale = eventResolutionService.resolve(
                finaleCommand
        );
        EventResolutionResult finaleReplay = eventResolutionService.resolve(
                finaleCommand
        );

        assertEquals(finale, finaleReplay);
        assertEquals(ExpeditionProgressStatus.COMPLETED,
                finale.expeditionStatus());
        assertNull(finale.nextNode());
        assertEquals(3L, inventoryQuantity("prism-dust"));
        assertEquals(2, rowCount("processed_event_resolution"));
    }

    @Test
    void shouldGateSanctuarySignalUntilPilotSkillIsUnlocked() {
        String userId = "signal-reader-sanctuary-user";
        platformService.execute(userId, new PlatformCommandRequest(
                "SELECT_PET",
                "select-pet-before-signal-reader",
                Map.of("petId", "spark-v1")
        ));
        assertEquals(1, jdbcTemplate.update("""
                UPDATE roadmap_user_state
                SET state_json = jsonb_set(
                    state_json,
                    '{seasonXp}',
                    '360'::jsonb
                )
                WHERE user_id = ?
                """, userId));
        jdbcTemplate.update(
                "UPDATE content_release SET is_active = false WHERE is_active"
        );
        assertEquals(1, jdbcTemplate.update("""
                UPDATE content_release
                SET is_active = true,
                    activated_at = COALESCE(activated_at, now())
                WHERE content_version = 'chapter-1-v13'
                """));
        jdbcTemplate.update("""
                INSERT INTO expedition_progress (
                    user_id, expedition_id, current_node_id,
                    progress_energy, required_energy, status,
                    unlocked_event_id, version, created_at, updated_at
                ) VALUES (?, ?, ?, 80, 80, 'EVENT_READY', ?, 51, now(), now())
                """,
                userId,
                StarterExpeditionContent.EXPEDITION_ID,
                StarterExpeditionContent.CONSTELLATION_SANCTUARY_NODE_ID,
                StarterExpeditionContent.CONSTELLATION_SANCTUARY_EVENT_ID
        );

        HomeSnapshotResponse lockedHome = homeService.getSnapshot(
                new HomeQuery(userId, LOCAL_DATE)
        );
        var lockedChoice = lockedHome.expedition().unlockedEvent()
                .lockedChoices().stream()
                .filter(choice -> StarterExpeditionContent
                        .SIGNAL_READER_SANCTUARY_CHOICE_ID.equals(
                                choice.choiceId()
                        ))
                .findFirst()
                .orElseThrow();

        assertEquals(
                StarterExpeditionContent.PILOT_SKILL_CHOICE_CONTENT_VERSION,
                lockedHome.contentVersion()
        );
        assertEquals("UNLOCKED_SKILL", lockedChoice.requirement().type());
        assertEquals(PlatformSkillIds.SIGNAL_READER,
                lockedChoice.requirement().itemId());
        EventChoiceSkillUnavailableException unavailable = assertThrows(
                EventChoiceSkillUnavailableException.class,
                () -> eventResolutionService.resolve(command(
                        userId,
                        StarterExpeditionContent.CONSTELLATION_SANCTUARY_EVENT_ID,
                        StarterExpeditionContent.SIGNAL_READER_SANCTUARY_CHOICE_ID,
                        "reject-locked-signal-reader"
                ))
        );
        assertEquals(PlatformSkillIds.SIGNAL_READER,
                unavailable.requiredSkillId());
        assertEquals(0, rowCount("processed_event_resolution"));
        assertEquals(0, rowCount("inventory_stack"));
        assertEquals(0, rowCount("pilot_progress"));
        assertEquals(0, rowCount("pet_progress"));

        platformService.execute(userId, new PlatformCommandRequest(
                "UNLOCK_SKILL",
                "unlock-signal-reader-before-sanctuary",
                Map.of("skillId", PlatformSkillIds.SIGNAL_READER)
        ));
        HomeSnapshotResponse unlockedHome = homeService.getSnapshot(
                new HomeQuery(userId, LOCAL_DATE)
        );
        assertTrue(unlockedHome.expedition().unlockedEvent().choices().stream()
                .anyMatch(choice -> StarterExpeditionContent
                        .SIGNAL_READER_SANCTUARY_CHOICE_ID.equals(
                                choice.choiceId()
                        )));

        EventResolutionCommand command = command(
                userId,
                StarterExpeditionContent.CONSTELLATION_SANCTUARY_EVENT_ID,
                StarterExpeditionContent.SIGNAL_READER_SANCTUARY_CHOICE_ID,
                "resolve-signal-reader-sanctuary"
        );
        EventResolutionResult result = eventResolutionService.resolve(command);
        EventResolutionResult replayed = eventResolutionService.resolve(command);

        assertEquals(result, replayed);
        assertEquals(ExpeditionProgressStatus.COMPLETED,
                result.expeditionStatus());
        assertEquals(96, result.pilot().experienceGained());
        assertEquals(50, result.pet().bondGained());
        assertEquals(StarterInventoryContent.ECHO_THREAD_ID,
                result.material().itemId());
        assertEquals(4, result.material().quantityGained());
        assertEquals(4L, inventoryQuantity(StarterInventoryContent.ECHO_THREAD_ID));
        assertEquals(1, rowCount("processed_event_resolution"));
        assertEquals(1, rowCount("pilot_progress"));
        assertEquals(1, rowCount("pet_progress"));
    }

    @Test
    void shouldCompleteSignalReaderSecretRouteExactlyOnce() {
        String userId = "signal-reader-secret-route-user";
        platformService.execute(userId, new PlatformCommandRequest(
                "SELECT_PET",
                "select-pet-before-secret-route",
                Map.of("petId", "spark-v1")
        ));
        assertEquals(1, jdbcTemplate.update("""
                UPDATE roadmap_user_state
                SET state_json = jsonb_set(
                    state_json,
                    '{seasonXp}',
                    '360'::jsonb
                )
                WHERE user_id = ?
                """, userId));
        jdbcTemplate.update(
                "UPDATE content_release SET is_active = false WHERE is_active"
        );
        assertEquals(1, jdbcTemplate.update("""
                UPDATE content_release
                SET is_active = true,
                    activated_at = COALESCE(activated_at, now())
                WHERE content_version = 'chapter-1-v14'
                """));
        platformService.execute(userId, new PlatformCommandRequest(
                "UNLOCK_SKILL",
                "unlock-signal-reader-before-secret-route",
                Map.of("skillId", PlatformSkillIds.SIGNAL_READER)
        ));
        jdbcTemplate.update("""
                INSERT INTO expedition_progress (
                    user_id, expedition_id, current_node_id,
                    progress_energy, required_energy, status,
                    unlocked_event_id, version, created_at, updated_at
                ) VALUES (?, ?, ?, 80, 80, 'EVENT_READY', ?, 51, now(), now())
                """,
                userId,
                StarterExpeditionContent.EXPEDITION_ID,
                StarterExpeditionContent.CONSTELLATION_SANCTUARY_NODE_ID,
                StarterExpeditionContent.CONSTELLATION_SANCTUARY_EVENT_ID
        );
        EventResolutionCommand sanctuaryCommand = command(
                userId,
                StarterExpeditionContent.CONSTELLATION_SANCTUARY_EVENT_ID,
                StarterExpeditionContent.SIGNAL_READER_SANCTUARY_CHOICE_ID,
                "open-signal-reader-secret-route"
        );

        EventResolutionResult sanctuary = eventResolutionService.resolve(
                sanctuaryCommand,
                false
        );
        EventResolutionResult sanctuaryReplay = eventResolutionService.resolve(
                sanctuaryCommand,
                false
        );

        assertEquals(sanctuary, sanctuaryReplay);
        assertEquals(ExpeditionProgressStatus.IN_PROGRESS,
                sanctuary.expeditionStatus());
        assertEquals(
                StarterExpeditionContent.HIDDEN_SIGNAL_OBSERVATORY_NODE_ID,
                sanctuary.nextNode().nodeId()
        );
        assertEquals(4L, inventoryQuantity(StarterInventoryContent.ECHO_THREAD_ID));
        assertEquals(1, jdbcTemplate.update("""
                UPDATE expedition_progress
                SET progress_energy = required_energy,
                    status = 'EVENT_READY',
                    unlocked_event_id = ?,
                    version = version + 1,
                    updated_at = now()
                WHERE user_id = ?
                  AND expedition_id = ?
                  AND current_node_id = ?
                """,
                StarterExpeditionContent.HIDDEN_SIGNAL_OBSERVATORY_EVENT_ID,
                userId,
                StarterExpeditionContent.EXPEDITION_ID,
                StarterExpeditionContent.HIDDEN_SIGNAL_OBSERVATORY_NODE_ID
        ));
        HomeSnapshotResponse hiddenHome = homeService.getSnapshot(
                new HomeQuery(userId, LOCAL_DATE)
        );
        assertEquals(
                StarterExpeditionContent
                        .SIGNAL_READER_SECRET_ROUTE_CONTENT_VERSION,
                hiddenHome.contentVersion()
        );
        assertEquals(
                StarterExpeditionContent.HIDDEN_SIGNAL_OBSERVATORY_EVENT_ID,
                hiddenHome.expedition().unlockedEvent().eventId()
        );
        assertEquals(2,
                hiddenHome.expedition().unlockedEvent().choices().size());
        EventResolutionCommand finaleCommand = command(
                userId,
                StarterExpeditionContent.HIDDEN_SIGNAL_OBSERVATORY_EVENT_ID,
                StarterExpeditionContent.CHART_HIDDEN_SECTOR_CHOICE_ID,
                "chart-hidden-sector"
        );

        EventResolutionResult finale = eventResolutionService.resolve(
                finaleCommand,
                false
        );
        EventResolutionResult finaleReplay = eventResolutionService.resolve(
                finaleCommand,
                false
        );

        assertEquals(finale, finaleReplay);
        assertEquals(ExpeditionProgressStatus.COMPLETED,
                finale.expeditionStatus());
        assertNull(finale.nextNode());
        assertEquals(112, finale.pilot().experienceGained());
        assertEquals(54, finale.pet().bondGained());
        assertEquals(4L, inventoryQuantity(StarterInventoryContent.PRISM_DUST_ID));
        assertEquals(2, rowCount("processed_event_resolution"));
        assertEquals(1, rowCount("pilot_progress"));
        assertEquals(1, rowCount("pet_progress"));
    }

    @Test
    void shouldGateAndCompleteTrailMemorySecretRouteExactlyOnce() {
        String userId = "trail-memory-secret-route-user";
        platformService.execute(userId, new PlatformCommandRequest(
                "SELECT_PET",
                "select-pet-before-trail-memory-route",
                Map.of("petId", "spark-v1")
        ));
        assertEquals(1, jdbcTemplate.update("""
                UPDATE roadmap_user_state
                SET state_json = jsonb_set(
                    state_json,
                    '{seasonXp}',
                    '100'::jsonb
                )
                WHERE user_id = ?
                """, userId));
        jdbcTemplate.update(
                "UPDATE content_release SET is_active = false WHERE is_active"
        );
        assertEquals(1, jdbcTemplate.update("""
                UPDATE content_release
                SET is_active = true,
                    activated_at = COALESCE(activated_at, now())
                WHERE content_version = 'chapter-1-v15'
                """));
        jdbcTemplate.update("""
                INSERT INTO expedition_progress (
                    user_id, expedition_id, current_node_id,
                    progress_energy, required_energy, status,
                    unlocked_event_id, version, created_at, updated_at
                ) VALUES (?, ?, ?, 90, 90, 'EVENT_READY', ?, 53, now(), now())
                """,
                userId,
                StarterExpeditionContent.EXPEDITION_ID,
                StarterExpeditionContent.HIDDEN_SIGNAL_OBSERVATORY_NODE_ID,
                StarterExpeditionContent.HIDDEN_SIGNAL_OBSERVATORY_EVENT_ID
        );

        HomeSnapshotResponse lockedHome = homeService.getSnapshot(
                new HomeQuery(userId, LOCAL_DATE)
        );
        var lockedChoice = lockedHome.expedition().unlockedEvent()
                .lockedChoices().stream()
                .filter(choice -> StarterExpeditionContent
                        .RECONSTRUCT_FORGOTTEN_ROUTE_CHOICE_ID.equals(
                                choice.choiceId()
                        ))
                .findFirst()
                .orElseThrow();

        assertEquals(
                StarterExpeditionContent.TRAIL_MEMORY_ROUTE_CONTENT_VERSION,
                lockedHome.contentVersion()
        );
        assertEquals("UNLOCKED_SKILL", lockedChoice.requirement().type());
        assertEquals(PlatformSkillIds.TRAIL_MEMORY,
                lockedChoice.requirement().itemId());
        EventResolutionCommand routeCommand = command(
                userId,
                StarterExpeditionContent.HIDDEN_SIGNAL_OBSERVATORY_EVENT_ID,
                StarterExpeditionContent
                        .RECONSTRUCT_FORGOTTEN_ROUTE_CHOICE_ID,
                "reject-locked-trail-memory-route"
        );
        EventChoiceSkillUnavailableException unavailable = assertThrows(
                EventChoiceSkillUnavailableException.class,
                () -> eventResolutionService.resolve(routeCommand, false)
        );
        assertEquals(PlatformSkillIds.TRAIL_MEMORY,
                unavailable.requiredSkillId());
        assertEquals(0, rowCount("processed_event_resolution"));
        assertEquals(0, rowCount("inventory_stack"));

        platformService.execute(userId, new PlatformCommandRequest(
                "UNLOCK_SKILL",
                "unlock-trail-memory-before-secret-route",
                Map.of("skillId", PlatformSkillIds.TRAIL_MEMORY)
        ));
        HomeSnapshotResponse unlockedHome = homeService.getSnapshot(
                new HomeQuery(userId, LOCAL_DATE)
        );
        assertTrue(unlockedHome.expedition().unlockedEvent().choices().stream()
                .anyMatch(choice -> StarterExpeditionContent
                        .RECONSTRUCT_FORGOTTEN_ROUTE_CHOICE_ID.equals(
                                choice.choiceId()
                        )));

        EventResolutionResult route = eventResolutionService.resolve(
                routeCommand,
                false
        );
        EventResolutionResult routeReplay = eventResolutionService.resolve(
                routeCommand,
                false
        );

        assertEquals(route, routeReplay);
        assertEquals(ExpeditionProgressStatus.IN_PROGRESS,
                route.expeditionStatus());
        assertEquals(
                StarterExpeditionContent.MEMORY_CONSTELLATION_NODE_ID,
                route.nextNode().nodeId()
        );
        assertEquals(3L,
                inventoryQuantity(StarterInventoryContent.DAWN_FRAGMENT_ID));
        assertEquals(1, jdbcTemplate.update("""
                UPDATE expedition_progress
                SET progress_energy = required_energy,
                    status = 'EVENT_READY',
                    unlocked_event_id = ?,
                    version = version + 1,
                    updated_at = now()
                WHERE user_id = ?
                  AND expedition_id = ?
                  AND current_node_id = ?
                """,
                StarterExpeditionContent.MEMORY_CONSTELLATION_EVENT_ID,
                userId,
                StarterExpeditionContent.EXPEDITION_ID,
                StarterExpeditionContent.MEMORY_CONSTELLATION_NODE_ID
        ));
        HomeSnapshotResponse memoryHome = homeService.getSnapshot(
                new HomeQuery(userId, LOCAL_DATE)
        );
        assertEquals(
                StarterExpeditionContent.MEMORY_CONSTELLATION_EVENT_ID,
                memoryHome.expedition().unlockedEvent().eventId()
        );
        assertEquals(2,
                memoryHome.expedition().unlockedEvent().choices().size());
        EventResolutionCommand finaleCommand = command(
                userId,
                StarterExpeditionContent.MEMORY_CONSTELLATION_EVENT_ID,
                StarterExpeditionContent.ARCHIVE_RETURN_PATH_CHOICE_ID,
                "archive-memory-return-path"
        );

        EventResolutionResult finale = eventResolutionService.resolve(
                finaleCommand,
                false
        );
        EventResolutionResult finaleReplay = eventResolutionService.resolve(
                finaleCommand,
                false
        );

        assertEquals(finale, finaleReplay);
        assertEquals(ExpeditionProgressStatus.COMPLETED,
                finale.expeditionStatus());
        assertNull(finale.nextNode());
        assertEquals(120, finale.pilot().experienceGained());
        assertEquals(58, finale.pet().bondGained());
        assertEquals(4L,
                inventoryQuantity(StarterInventoryContent.ION_BLOOM_ID));
        assertEquals(2, rowCount("processed_event_resolution"));
        assertEquals(1, rowCount("pilot_progress"));
        assertEquals(1, rowCount("pet_progress"));
    }

    @Test
    void shouldGateAndCompleteEnergyDisciplineRouteExactlyOnce() {
        String userId = "energy-discipline-route-user";
        platformService.execute(userId, new PlatformCommandRequest(
                "SELECT_PET",
                "select-pet-before-energy-discipline-route",
                Map.of("petId", "spark-v1")
        ));
        assertEquals(1, jdbcTemplate.update("""
                UPDATE roadmap_user_state
                SET state_json = jsonb_set(
                    state_json,
                    '{seasonXp}',
                    '220'::jsonb
                )
                WHERE user_id = ?
                """, userId));
        jdbcTemplate.update(
                "UPDATE content_release SET is_active = false WHERE is_active"
        );
        assertEquals(1, jdbcTemplate.update("""
                UPDATE content_release
                SET is_active = true,
                    activated_at = COALESCE(activated_at, now())
                WHERE content_version = 'chapter-1-v16'
                """));
        jdbcTemplate.update("""
                INSERT INTO expedition_progress (
                    user_id, expedition_id, current_node_id,
                    progress_energy, required_energy, status,
                    unlocked_event_id, version, created_at, updated_at
                ) VALUES (?, ?, ?, 95, 95, 'EVENT_READY', ?, 55, now(), now())
                """,
                userId,
                StarterExpeditionContent.EXPEDITION_ID,
                StarterExpeditionContent.MEMORY_CONSTELLATION_NODE_ID,
                StarterExpeditionContent.MEMORY_CONSTELLATION_EVENT_ID
        );

        HomeSnapshotResponse lockedHome = homeService.getSnapshot(
                new HomeQuery(userId, LOCAL_DATE)
        );
        var lockedChoice = lockedHome.expedition().unlockedEvent()
                .lockedChoices().stream()
                .filter(choice -> StarterExpeditionContent
                        .STABILIZE_DAWN_CURRENT_CHOICE_ID.equals(
                                choice.choiceId()
                        ))
                .findFirst()
                .orElseThrow();

        assertEquals(
                StarterExpeditionContent
                        .ENERGY_DISCIPLINE_ROUTE_CONTENT_VERSION,
                lockedHome.contentVersion()
        );
        assertEquals("UNLOCKED_SKILL", lockedChoice.requirement().type());
        assertEquals(PlatformSkillIds.ENERGY_DISCIPLINE,
                lockedChoice.requirement().itemId());
        EventResolutionCommand routeCommand = command(
                userId,
                StarterExpeditionContent.MEMORY_CONSTELLATION_EVENT_ID,
                StarterExpeditionContent.STABILIZE_DAWN_CURRENT_CHOICE_ID,
                "reject-locked-energy-discipline-route"
        );
        EventChoiceSkillUnavailableException unavailable = assertThrows(
                EventChoiceSkillUnavailableException.class,
                () -> eventResolutionService.resolve(routeCommand, false)
        );
        assertEquals(PlatformSkillIds.ENERGY_DISCIPLINE,
                unavailable.requiredSkillId());
        assertEquals(0, rowCount("processed_event_resolution"));
        assertEquals(0, rowCount("inventory_stack"));

        platformService.execute(userId, new PlatformCommandRequest(
                "UNLOCK_SKILL",
                "unlock-energy-discipline-before-route",
                Map.of("skillId", PlatformSkillIds.ENERGY_DISCIPLINE)
        ));
        HomeSnapshotResponse unlockedHome = homeService.getSnapshot(
                new HomeQuery(userId, LOCAL_DATE)
        );
        assertTrue(unlockedHome.expedition().unlockedEvent().choices().stream()
                .anyMatch(choice -> StarterExpeditionContent
                        .STABILIZE_DAWN_CURRENT_CHOICE_ID.equals(
                                choice.choiceId()
                        )));

        EventResolutionResult route = eventResolutionService.resolve(
                routeCommand,
                false
        );
        EventResolutionResult routeReplay = eventResolutionService.resolve(
                routeCommand,
                false
        );

        assertEquals(route, routeReplay);
        assertEquals(ExpeditionProgressStatus.IN_PROGRESS,
                route.expeditionStatus());
        assertEquals(
                StarterExpeditionContent.DAWN_MERIDIAN_NODE_ID,
                route.nextNode().nodeId()
        );
        assertEquals(112, route.pilot().experienceGained());
        assertEquals(70, route.pet().bondGained());
        assertEquals(3L,
                inventoryQuantity(StarterInventoryContent.ION_BLOOM_ID));
        assertEquals(1, jdbcTemplate.update("""
                UPDATE expedition_progress
                SET progress_energy = required_energy,
                    status = 'EVENT_READY',
                    unlocked_event_id = ?,
                    version = version + 1,
                    updated_at = now()
                WHERE user_id = ?
                  AND expedition_id = ?
                  AND current_node_id = ?
                """,
                StarterExpeditionContent.DAWN_MERIDIAN_EVENT_ID,
                userId,
                StarterExpeditionContent.EXPEDITION_ID,
                StarterExpeditionContent.DAWN_MERIDIAN_NODE_ID
        ));
        jdbcTemplate.update(
                "UPDATE content_release SET is_active = false WHERE is_active"
        );
        assertEquals(1, jdbcTemplate.update("""
                UPDATE content_release
                SET is_active = true,
                    activated_at = COALESCE(activated_at, now())
                WHERE content_version = 'chapter-1-v15'
                """));

        HomeSnapshotResponse dawnHome = homeService.getSnapshot(
                new HomeQuery(userId, LOCAL_DATE)
        );
        assertEquals(
                StarterExpeditionContent.TRAIL_MEMORY_ROUTE_CONTENT_VERSION,
                dawnHome.contentVersion()
        );
        assertEquals(
                StarterExpeditionContent.DAWN_MERIDIAN_EVENT_ID,
                dawnHome.expedition().unlockedEvent().eventId()
        );
        assertEquals(2,
                dawnHome.expedition().unlockedEvent().choices().size());
        EventResolutionCommand finaleCommand = command(
                userId,
                StarterExpeditionContent.DAWN_MERIDIAN_EVENT_ID,
                StarterExpeditionContent.ANCHOR_DAWN_FLOW_CHOICE_ID,
                "anchor-dawn-flow-after-rollback"
        );

        EventResolutionResult finale = eventResolutionService.resolve(
                finaleCommand,
                false
        );
        EventResolutionResult finaleReplay = eventResolutionService.resolve(
                finaleCommand,
                false
        );

        assertEquals(finale, finaleReplay);
        assertEquals(ExpeditionProgressStatus.COMPLETED,
                finale.expeditionStatus());
        assertNull(finale.nextNode());
        assertEquals(132, finale.pilot().experienceGained());
        assertEquals(64, finale.pet().bondGained());
        assertEquals(5L,
                inventoryQuantity(StarterInventoryContent.DAWN_FRAGMENT_ID));
        assertEquals(2, rowCount("processed_event_resolution"));
        assertEquals(1, rowCount("pilot_progress"));
        assertEquals(1, rowCount("pet_progress"));
    }

    @Test
    void shouldGateAndCompleteSteadyStepRouteExactlyOnce() {
        String userId = "steady-step-route-user";
        platformService.execute(userId, new PlatformCommandRequest(
                "SELECT_PET",
                "select-pet-before-steady-step-route",
                Map.of("petId", "spark-v1")
        ));
        jdbcTemplate.update(
                "UPDATE content_release SET is_active = false WHERE is_active"
        );
        assertEquals(1, jdbcTemplate.update("""
                UPDATE content_release
                SET is_active = true,
                    activated_at = COALESCE(activated_at, now())
                WHERE content_version = 'chapter-1-v17'
                """));
        jdbcTemplate.update("""
                INSERT INTO expedition_progress (
                    user_id, expedition_id, current_node_id,
                    progress_energy, required_energy, status,
                    unlocked_event_id, version, created_at, updated_at
                ) VALUES (?, ?, ?, 100, 100, 'EVENT_READY', ?, 56, now(), now())
                """,
                userId,
                StarterExpeditionContent.EXPEDITION_ID,
                StarterExpeditionContent.DAWN_MERIDIAN_NODE_ID,
                StarterExpeditionContent.DAWN_MERIDIAN_EVENT_ID
        );

        HomeSnapshotResponse lockedHome = homeService.getSnapshot(
                new HomeQuery(userId, LOCAL_DATE)
        );
        var lockedChoice = lockedHome.expedition().unlockedEvent()
                .lockedChoices().stream()
                .filter(choice -> StarterExpeditionContent
                        .CROSS_FIRST_LIGHT_CAUSEWAY_CHOICE_ID.equals(
                                choice.choiceId()
                        ))
                .findFirst()
                .orElseThrow();

        assertEquals(
                StarterExpeditionContent.STEADY_STEP_ROUTE_CONTENT_VERSION,
                lockedHome.contentVersion()
        );
        assertEquals("UNLOCKED_SKILL", lockedChoice.requirement().type());
        assertEquals(PlatformSkillIds.STEADY_STEP,
                lockedChoice.requirement().itemId());
        EventResolutionCommand routeCommand = command(
                userId,
                StarterExpeditionContent.DAWN_MERIDIAN_EVENT_ID,
                StarterExpeditionContent.CROSS_FIRST_LIGHT_CAUSEWAY_CHOICE_ID,
                "reject-locked-steady-step-route"
        );
        EventChoiceSkillUnavailableException unavailable = assertThrows(
                EventChoiceSkillUnavailableException.class,
                () -> eventResolutionService.resolve(routeCommand, false)
        );
        assertEquals(PlatformSkillIds.STEADY_STEP,
                unavailable.requiredSkillId());
        assertEquals(0, rowCount("processed_event_resolution"));
        assertEquals(0, rowCount("inventory_stack"));

        platformService.execute(userId, new PlatformCommandRequest(
                "UNLOCK_SKILL",
                "unlock-steady-step-before-route",
                Map.of("skillId", PlatformSkillIds.STEADY_STEP)
        ));
        HomeSnapshotResponse unlockedHome = homeService.getSnapshot(
                new HomeQuery(userId, LOCAL_DATE)
        );
        assertTrue(unlockedHome.expedition().unlockedEvent().choices().stream()
                .anyMatch(choice -> StarterExpeditionContent
                        .CROSS_FIRST_LIGHT_CAUSEWAY_CHOICE_ID.equals(
                                choice.choiceId()
                        )));

        EventResolutionResult route = eventResolutionService.resolve(
                routeCommand,
                false
        );
        EventResolutionResult routeReplay = eventResolutionService.resolve(
                routeCommand,
                false
        );

        assertEquals(route, routeReplay);
        assertEquals(ExpeditionProgressStatus.IN_PROGRESS,
                route.expeditionStatus());
        assertEquals(
                StarterExpeditionContent.FIRST_LIGHT_CAUSEWAY_NODE_ID,
                route.nextNode().nodeId()
        );
        assertEquals(118, route.pilot().experienceGained());
        assertEquals(76, route.pet().bondGained());
        assertEquals(4L,
                inventoryQuantity(StarterInventoryContent.PRISM_DUST_ID));
        assertEquals(1, jdbcTemplate.update("""
                UPDATE expedition_progress
                SET progress_energy = required_energy,
                    status = 'EVENT_READY',
                    unlocked_event_id = ?,
                    version = version + 1,
                    updated_at = now()
                WHERE user_id = ?
                  AND expedition_id = ?
                  AND current_node_id = ?
                """,
                StarterExpeditionContent.FIRST_LIGHT_CAUSEWAY_EVENT_ID,
                userId,
                StarterExpeditionContent.EXPEDITION_ID,
                StarterExpeditionContent.FIRST_LIGHT_CAUSEWAY_NODE_ID
        ));
        jdbcTemplate.update(
                "UPDATE content_release SET is_active = false WHERE is_active"
        );
        assertEquals(1, jdbcTemplate.update("""
                UPDATE content_release
                SET is_active = true,
                    activated_at = COALESCE(activated_at, now())
                WHERE content_version = 'chapter-1-v16'
                """));

        HomeSnapshotResponse causewayHome = homeService.getSnapshot(
                new HomeQuery(userId, LOCAL_DATE)
        );
        assertEquals(
                StarterExpeditionContent
                        .ENERGY_DISCIPLINE_ROUTE_CONTENT_VERSION,
                causewayHome.contentVersion()
        );
        assertEquals(
                StarterExpeditionContent.FIRST_LIGHT_CAUSEWAY_EVENT_ID,
                causewayHome.expedition().unlockedEvent().eventId()
        );
        assertEquals(2,
                causewayHome.expedition().unlockedEvent().choices().size());
        EventResolutionCommand finaleCommand = command(
                userId,
                StarterExpeditionContent.FIRST_LIGHT_CAUSEWAY_EVENT_ID,
                StarterExpeditionContent.MAP_FIRST_LIGHT_PULSE_CHOICE_ID,
                "map-first-light-pulse-after-rollback"
        );

        EventResolutionResult finale = eventResolutionService.resolve(
                finaleCommand,
                false
        );
        EventResolutionResult finaleReplay = eventResolutionService.resolve(
                finaleCommand,
                false
        );

        assertEquals(finale, finaleReplay);
        assertEquals(ExpeditionProgressStatus.COMPLETED,
                finale.expeditionStatus());
        assertNull(finale.nextNode());
        assertEquals(144, finale.pilot().experienceGained());
        assertEquals(72, finale.pet().bondGained());
        assertEquals(6L,
                inventoryQuantity(StarterInventoryContent.ION_BLOOM_ID));
        assertEquals(2, rowCount("processed_event_resolution"));
        assertEquals(1, rowCount("pilot_progress"));
        assertEquals(1, rowCount("pet_progress"));
    }

    @Test
    void shouldSerializeEventRewardWithConcurrentPetSelection() throws Exception {
        String userId = "concurrent-pet-user";
        platformService.execute(userId, new PlatformCommandRequest(
                "SELECT_PET",
                "select-spark-before-race",
                Map.of("petId", "spark-v1")
        ));
        prepareFirstEvent(userId);

        ExecutorService executor = Executors.newFixedThreadPool(2);
        CountDownLatch selectionSaved = new CountDownLatch(1);
        CountDownLatch allowSelectionCommit = new CountDownLatch(1);
        TransactionTemplate transaction = new TransactionTemplate(transactionManager);
        try {
            Future<?> selection = executor.submit(() ->
                    transaction.executeWithoutResult(status -> {
                        platformService.execute(userId, new PlatformCommandRequest(
                                "SELECT_PET",
                                "select-moss-during-race",
                                Map.of("petId", "moss-v1")
                        ));
                        selectionSaved.countDown();
                        awaitLatch(allowSelectionCommit);
                    })
            );
            assertTrue(selectionSaved.await(10, TimeUnit.SECONDS));

            Future<EventResolutionResult> event = executor.submit(() ->
                    eventResolutionService.resolve(command(
                            userId,
                            StarterExpeditionContent.FIRST_EVENT_ID,
                            "analyze-signal",
                            "resolve-during-selection"
                    ))
            );

            awaitAdvisoryLockWait();
            allowSelectionCommit.countDown();

            selection.get(10, TimeUnit.SECONDS);
            EventResolutionResult result = event.get(10, TimeUnit.SECONDS);

            assertEquals("moss-v1", result.pet().petId());
            assertEquals("moss-v1", jdbcTemplate.queryForObject("""
                    SELECT pet_id
                    FROM pet_progress
                    WHERE user_id = ?
                    """, String.class, userId));
            assertEquals(0, jdbcTemplate.queryForObject("""
                    SELECT count(*)
                    FROM pet_progress
                    WHERE user_id = ?
                      AND pet_id = 'spark-v1'
                    """, Integer.class, userId));
        } finally {
            allowSelectionCommit.countDown();
            executor.shutdownNow();
        }
    }

    @Test
    void shouldTimestampResolutionAfterWaitingForExpeditionLock() throws Exception {
        String userId = "resolution-lock-time-user";
        String idempotencyKey = "resolution-lock-time";
        Instant lockReleaseTime = Instant.parse("2026-07-26T12:00:00Z");
        prepareFirstEvent(userId);

        MutableClock clock = new MutableClock(lockReleaseTime.minusSeconds(30));
        EventResolutionService orderedService = new EventResolutionService(
                expeditionRepository,
                eventResolutionRepository,
                progressionService,
                inventoryService,
                content,
                clock
        );
        EventResolutionCommand command = command(
                userId,
                StarterExpeditionContent.FIRST_EVENT_ID,
                "analyze-signal",
                idempotencyKey
        );
        TransactionTemplate transaction = new TransactionTemplate(transactionManager);
        ExecutorService executor = Executors.newSingleThreadExecutor();

        EventResolutionResult result;
        try {
            try (Connection blocker = dataSource.getConnection()) {
                blocker.setAutoCommit(false);
                try (PreparedStatement lock = blocker.prepareStatement("""
                        SELECT pg_advisory_xact_lock(hashtextextended(?, 0))
                        """)) {
                    lock.setString(1, expeditionLockKey(userId));
                    lock.execute();
                }

                Future<EventResolutionResult> pending = executor.submit(() ->
                        transaction.execute(status -> orderedService.resolve(command))
                );
                awaitAdvisoryLockWait();
                clock.set(lockReleaseTime);
                blocker.commit();
                result = pending.get(10, TimeUnit.SECONDS);
            }
        } finally {
            executor.shutdownNow();
        }

        assertEquals(lockReleaseTime, result.serverTime());
        assertEquals(lockReleaseTime, timestamp("""
                SELECT server_time
                FROM processed_event_resolution
                WHERE user_id = ?
                  AND idempotency_key = ?
                """, userId, idempotencyKey));
        assertEquals(lockReleaseTime, timestamp("""
                SELECT updated_at
                FROM expedition_progress
                WHERE user_id = ?
                """, userId));
        assertEquals(lockReleaseTime, timestamp("""
                SELECT updated_at
                FROM pilot_progress
                WHERE user_id = ?
                """, userId));
        assertEquals(lockReleaseTime, timestamp("""
                SELECT updated_at
                FROM pet_progress
                WHERE user_id = ?
                """, userId));
        assertEquals(result, eventResolutionService.resolve(command));
    }

    private void prepareFirstEvent(String userId) {
        activitySyncService.synchronize(new ActivitySyncCommand(
                userId,
                "event-device",
                LOCAL_DATE,
                ZoneId.of("Europe/Berlin"),
                10_000,
                List.of(),
                "event-cursor",
                "activity-" + userId,
                null
        ));
        expeditionAdvanceService.advance(new ExpeditionAdvanceCommand(
                userId,
                StarterExpeditionContent.EXPEDITION_ID,
                30,
                "advance-first-" + userId
        ));
    }

    private EventResolutionCommand command(
            String userId,
            String eventId,
            String choiceId,
            String idempotencyKey
    ) {
        return new EventResolutionCommand(userId, eventId, choiceId, idempotencyKey);
    }

    private void awaitLatch(CountDownLatch latch) {
        awaitLatch(latch, "commit pet selection");
    }

    private void awaitLatch(CountDownLatch latch, String action) {
        try {
            if (!latch.await(10, TimeUnit.SECONDS)) {
                throw new IllegalStateException("Timed out waiting to " + action);
            }
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException(action + " wait interrupted", exception);
        }
    }

    private void awaitAdvisoryLockWait() throws InterruptedException {
        long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(10);
        while (System.nanoTime() < deadline) {
            Integer waiting = jdbcTemplate.queryForObject("""
                    SELECT count(*)
                    FROM pg_stat_activity
                    WHERE datname = current_database()
                      AND wait_event_type = 'Lock'
                      AND lower(wait_event) = 'advisory'
                    """, Integer.class);
            if (waiting != null && waiting > 0) {
                return;
            }
            Thread.sleep(25);
        }
        throw new AssertionError("Event resolution did not wait for an advisory lock");
    }

    private String expeditionLockKey(String userId) {
        return userId.length()
                + ":"
                + userId
                + ":"
                + StarterExpeditionContent.EXPEDITION_ID;
    }

    private String accountLockKey(String userId) {
        return userId.length() + ":" + userId;
    }

    private Instant timestamp(String sql, Object... arguments) {
        return jdbcTemplate.queryForObject(
                sql,
                Timestamp.class,
                arguments
        ).toInstant();
    }

    private int rowCount(String table) {
        return jdbcTemplate.queryForObject("SELECT count(*) FROM " + table, Integer.class);
    }

    private int milestoneCount(String userId, String milestone) {
        Integer count = jdbcTemplate.queryForObject("""
                SELECT count(*)
                FROM first_journey_milestone
                WHERE user_id = ?
                  AND milestone = ?
                """, Integer.class, userId, milestone);
        return count == null ? 0 : count;
    }

    private int pilotExperience() {
        return jdbcTemplate.queryForObject(
                "SELECT current_experience FROM pilot_progress",
                Integer.class
        );
    }

    private int petBond() {
        return jdbcTemplate.queryForObject(
                "SELECT bond FROM pet_progress",
                Integer.class
        );
    }

    private long walletBalance() {
        return jdbcTemplate.queryForObject(
                "SELECT balance FROM economy_wallet WHERE currency_code = 'ENERGY'",
                Long.class
        );
    }

    private long inventoryQuantity(String itemId) {
        return jdbcTemplate.queryForObject(
                "SELECT quantity FROM inventory_stack WHERE item_id = ?",
                Long.class,
                itemId
        );
    }

    private String expeditionStatus() {
        return jdbcTemplate.queryForObject(
                "SELECT status FROM expedition_progress",
                String.class
        );
    }

    private String currentNodeId() {
        return jdbcTemplate.queryForObject(
                "SELECT current_node_id FROM expedition_progress",
                String.class
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
