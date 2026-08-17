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
import java.util.Optional;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import javax.sql.DataSource;

import com.walkingrpg.backend.activity.application.ActivitySyncService;
import com.walkingrpg.backend.activity.domain.ActivitySyncCommand;
import com.walkingrpg.backend.economy.application.EconomyService;
import com.walkingrpg.backend.economy.domain.InsufficientEnergyException;
import com.walkingrpg.backend.expedition.application.ExpeditionAdvanceService;
import com.walkingrpg.backend.expedition.application.StarterExpeditionContent;
import com.walkingrpg.backend.expedition.domain.ExpeditionAdvanceCommand;
import com.walkingrpg.backend.expedition.domain.ExpeditionAdvanceResult;
import com.walkingrpg.backend.expedition.domain.ExpeditionIdempotencyScope;
import com.walkingrpg.backend.expedition.domain.ExpeditionProgressState;
import com.walkingrpg.backend.expedition.domain.ExpeditionProgressStatus;
import com.walkingrpg.backend.expedition.domain.ProcessedExpeditionAdvance;
import com.walkingrpg.backend.expedition.domain.ProcessedExpeditionJourneyStart;
import org.junit.jupiter.api.AfterEach;
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
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

@SpringBootTest
@ActiveProfiles("test")
@Testcontainers
class ExpeditionAdvanceIntegrationTest {

    private static final LocalDate ACTIVITY_DATE = LocalDate.of(2026, 7, 25);

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
    private ExpeditionAdvanceService expeditionService;

    @Autowired
    private ExpeditionRepository expeditionRepository;

    @Autowired
    private EventResolutionRepository eventResolutionRepository;

    @Autowired
    private EconomyService economyService;

    @Autowired
    private StarterExpeditionContent content;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private DataSource dataSource;

    @Autowired
    private PlatformTransactionManager transactionManager;

    private ExecutorService executor;

    @BeforeEach
    void cleanDatabase() {
        jdbcTemplate.update("DELETE FROM inventory_ledger");
        jdbcTemplate.update("DELETE FROM inventory_stack");
        jdbcTemplate.update("DELETE FROM processed_expedition_advance");
        jdbcTemplate.update("DELETE FROM expedition_progress");
        jdbcTemplate.update("DELETE FROM processed_activity_sync");
        jdbcTemplate.update("DELETE FROM economy_ledger");
        jdbcTemplate.update("DELETE FROM activity_sync_state");
        jdbcTemplate.update("DELETE FROM economy_wallet");
        jdbcTemplate.update("DELETE FROM app_device");
        jdbcTemplate.update("DELETE FROM app_user");
    }

    @AfterEach
    void stopExecutor() {
        if (executor != null) {
            executor.shutdownNow();
        }
    }

    @Test
    void shouldPersistDebitProgressEventAndIdempotentResponse() {
        seedEnergy("expedition-user", "device-1", 6_842, "sync-1");
        ExpeditionAdvanceCommand command = advanceCommand(
                "expedition-user",
                30,
                "advance-1"
        );

        ExpeditionAdvanceResult first = expeditionService.advance(command);
        ExpeditionAdvanceResult replayed = expeditionService.advance(command);

        assertEquals(first, replayed);
        assertEquals(38, first.energyBalanceAfter());
        assertEquals(30, first.progressAfter());
        assertEquals(ExpeditionProgressStatus.EVENT_READY, first.status());
        assertNotNull(first.unlockedEvent());
        assertEquals(38L, walletBalance("expedition-user"));
        assertEquals(38L, ledgerSum("expedition-user"));
        assertEquals(2, rowCount("economy_ledger"));
        assertEquals(1, rowCount("expedition_progress"));
        assertEquals(1, rowCount("processed_expedition_advance"));
        assertEquals(1, milestoneCount("expedition-user", "FIRST_NODE_REACHED"));
    }

    @Test
    void shouldRollbackEverythingWhenBalanceIsInsufficient() {
        seedEnergy("poor-user", "device-poor", 500, "sync-poor");

        assertThrows(
                InsufficientEnergyException.class,
                () -> expeditionService.advance(advanceCommand(
                        "poor-user",
                        10,
                        "advance-poor"
                ))
        );

        assertEquals(5L, walletBalance("poor-user"));
        assertEquals(5L, ledgerSum("poor-user"));
        assertEquals(1, rowCount("economy_ledger"));
        assertEquals(0, rowCount("expedition_progress"));
        assertEquals(0, rowCount("processed_expedition_advance"));
        assertEquals(0, milestoneCount("rollback-user", "FIRST_NODE_REACHED"));
    }

    @Test
    void shouldSerializeConcurrentPartialAdvances() throws Exception {
        seedEnergy("concurrent-user", "device-concurrent", 6_000, "sync-concurrent");
        executor = Executors.newFixedThreadPool(2);
        CountDownLatch ready = new CountDownLatch(2);
        CountDownLatch start = new CountDownLatch(1);

        Future<ExpeditionAdvanceResult> first = executor.submit(
                () -> synchronizedAdvance(
                        ready,
                        start,
                        advanceCommand("concurrent-user", 20, "advance-a")
                )
        );
        Future<ExpeditionAdvanceResult> second = executor.submit(
                () -> synchronizedAdvance(
                        ready,
                        start,
                        advanceCommand("concurrent-user", 10, "advance-b")
                )
        );

        ready.await(10, TimeUnit.SECONDS);
        start.countDown();
        first.get(20, TimeUnit.SECONDS);
        second.get(20, TimeUnit.SECONDS);

        assertEquals(30L, walletBalance("concurrent-user"));
        assertEquals(30L, expeditionProgress("concurrent-user"));
        assertEquals("EVENT_READY", expeditionStatus("concurrent-user"));
        assertEquals(2, rowCount("processed_expedition_advance"));
        assertEquals(3, rowCount("economy_ledger"));
    }

    @Test
    void shouldTimestampAdvanceAfterWaitingForExpeditionLock() throws Exception {
        String userId = "advance-lock-time-user";
        String idempotencyKey = "advance-lock-time";
        Instant lockReleaseTime = Instant.parse("2026-07-25T12:00:00Z");
        seedEnergy(userId, "device-lock-time", 6_000, "sync-lock-time");

        MutableClock clock = new MutableClock(lockReleaseTime.minusSeconds(30));
        CountDownLatch lockAttempted = new CountDownLatch(1);
        ExpeditionAdvanceService orderedService = new ExpeditionAdvanceService(
                new LockSignallingRepository(expeditionRepository, lockAttempted),
                eventResolutionRepository,
                economyService,
                content,
                clock
        );
        ExpeditionAdvanceCommand command = advanceCommand(
                userId,
                10,
                idempotencyKey
        );
        TransactionTemplate transaction = new TransactionTemplate(transactionManager);
        executor = Executors.newSingleThreadExecutor();

        ExpeditionAdvanceResult result;
        try (Connection blocker = dataSource.getConnection()) {
            blocker.setAutoCommit(false);
            try (PreparedStatement lock = blocker.prepareStatement("""
                    SELECT pg_advisory_xact_lock(hashtextextended(?, 0))
                    """)) {
                lock.setString(1, expeditionLockKey(userId));
                lock.execute();
            }

            Future<ExpeditionAdvanceResult> pending = executor.submit(() ->
                    transaction.execute(status -> orderedService.advance(command))
            );
            assertTrue(lockAttempted.await(5, TimeUnit.SECONDS));
            awaitAdvisoryLockWait();
            clock.set(lockReleaseTime);
            blocker.commit();
            result = pending.get(10, TimeUnit.SECONDS);
        }

        assertEquals(lockReleaseTime, result.serverTime());
        assertEquals(lockReleaseTime, timestamp("""
                SELECT server_time
                FROM processed_expedition_advance
                WHERE user_id = 'advance-lock-time-user'
                  AND idempotency_key = 'advance-lock-time'
                """));
        assertEquals(lockReleaseTime, timestamp("""
                SELECT updated_at
                FROM expedition_progress
                WHERE user_id = 'advance-lock-time-user'
                """));
        assertEquals(lockReleaseTime, timestamp("""
                SELECT created_at
                FROM economy_ledger
                WHERE user_id = 'advance-lock-time-user'
                  AND source_type = 'EXPEDITION_ADVANCE'
                  AND source_key = '21:starter-expedition-v1:advance-lock-time'
                """));
        assertEquals(result, expeditionService.advance(command));
    }

    @Test
    void shouldRollbackDebitAndProgressWhenProcessedResponseSaveFails() {
        seedEnergy("rollback-user", "device-rollback", 6_000, "sync-rollback");
        ExpeditionRepository failingRepository = new FailingProcessedSaveRepository(
                expeditionRepository
        );
        ExpeditionAdvanceService failingService = new ExpeditionAdvanceService(
                failingRepository,
                eventResolutionRepository,
                economyService,
                content,
                Clock.fixed(Instant.parse("2026-07-25T12:00:00Z"), ZoneOffset.UTC)
        );
        TransactionTemplate transaction = new TransactionTemplate(transactionManager);

        assertThrows(
                IllegalStateException.class,
                () -> transaction.executeWithoutResult(status -> failingService.advance(
                        advanceCommand("rollback-user", 30, "advance-rollback")
                ))
        );

        assertEquals(60L, walletBalance("rollback-user"));
        assertEquals(60L, ledgerSum("rollback-user"));
        assertEquals(1, rowCount("economy_ledger"));
        assertEquals(0, rowCount("expedition_progress"));
        assertEquals(0, rowCount("processed_expedition_advance"));
    }

    private ExpeditionAdvanceResult synchronizedAdvance(
            CountDownLatch ready,
            CountDownLatch start,
            ExpeditionAdvanceCommand command
    ) throws InterruptedException {
        ready.countDown();
        start.await(10, TimeUnit.SECONDS);
        return expeditionService.advance(command);
    }

    private void seedEnergy(
            String userId,
            String deviceId,
            long total,
            String idempotencyKey
    ) {
        activitySyncService.synchronize(new ActivitySyncCommand(
                userId,
                deviceId,
                ACTIVITY_DATE,
                ZoneId.of("Europe/Berlin"),
                total,
                List.of(),
                "cursor-" + userId,
                idempotencyKey,
                null
        ));
    }

    private ExpeditionAdvanceCommand advanceCommand(
            String userId,
            long energy,
            String key
    ) {
        return new ExpeditionAdvanceCommand(
                userId,
                StarterExpeditionContent.EXPEDITION_ID,
                energy,
                key
        );
    }

    private int rowCount(String table) {
        return jdbcTemplate.queryForObject("SELECT count(*) FROM " + table, Integer.class);
    }

    private int milestoneCount(String userId, String milestone) {
        return jdbcTemplate.queryForObject("""
                SELECT count(*)
                FROM first_journey_milestone
                WHERE user_id = ?
                  AND milestone = ?
                """, Integer.class, userId, milestone);
    }

    private Instant timestamp(String sql) {
        return jdbcTemplate.queryForObject(sql, Timestamp.class).toInstant();
    }

    private String expeditionLockKey(String userId) {
        return userId.length()
                + ":"
                + userId
                + ":"
                + StarterExpeditionContent.EXPEDITION_ID;
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
        throw new AssertionError("Expedition advance did not wait for the advisory lock");
    }

    private long walletBalance(String userId) {
        return jdbcTemplate.queryForObject(
                "SELECT balance FROM economy_wallet WHERE user_id = ? AND currency_code = 'ENERGY'",
                Long.class,
                userId
        );
    }

    private long ledgerSum(String userId) {
        Long value = jdbcTemplate.queryForObject(
                "SELECT COALESCE(sum(amount), 0) FROM economy_ledger WHERE user_id = ?",
                Long.class,
                userId
        );
        return value == null ? 0 : value;
    }

    private long expeditionProgress(String userId) {
        return jdbcTemplate.queryForObject(
                "SELECT progress_energy FROM expedition_progress WHERE user_id = ?",
                Long.class,
                userId
        );
    }

    private String expeditionStatus(String userId) {
        return jdbcTemplate.queryForObject(
                "SELECT status FROM expedition_progress WHERE user_id = ?",
                String.class,
                userId
        );
    }

    private static final class FailingProcessedSaveRepository
            implements ExpeditionRepository {

        private final ExpeditionRepository delegate;

        private FailingProcessedSaveRepository(ExpeditionRepository delegate) {
            this.delegate = delegate;
        }

        @Override
        public void acquireLock(String userId, String expeditionId) {
            delegate.acquireLock(userId, expeditionId);
        }

        @Override
        public Optional<ExpeditionProgressState> findState(
                String userId,
                String expeditionId
        ) {
            return delegate.findState(userId, expeditionId);
        }

        @Override
        public void saveState(
                String userId,
                String expeditionId,
                ExpeditionProgressState state,
                Instant updatedAt
        ) {
            delegate.saveState(userId, expeditionId, state, updatedAt);
        }

        @Override
        public Optional<ProcessedExpeditionAdvance> findProcessed(
                ExpeditionIdempotencyScope scope
        ) {
            return delegate.findProcessed(scope);
        }

        @Override
        public void saveProcessed(
                ExpeditionIdempotencyScope scope,
                ProcessedExpeditionAdvance processed
        ) {
            throw new IllegalStateException("forced processed response failure");
        }

        @Override
        public long findJourneyNumber(String userId, String expeditionId) {
            return delegate.findJourneyNumber(userId, expeditionId);
        }

        @Override
        public void saveJourneyNumber(
                String userId,
                String expeditionId,
                long journeyNumber,
                Instant updatedAt
        ) {
            delegate.saveJourneyNumber(
                    userId,
                    expeditionId,
                    journeyNumber,
                    updatedAt
            );
        }

        @Override
        public Optional<ProcessedExpeditionJourneyStart> findProcessedJourney(
                ExpeditionIdempotencyScope scope
        ) {
            return delegate.findProcessedJourney(scope);
        }

        @Override
        public void saveProcessedJourney(
                ExpeditionIdempotencyScope scope,
                ProcessedExpeditionJourneyStart processed
        ) {
            delegate.saveProcessedJourney(scope, processed);
        }
    }

    private static final class LockSignallingRepository
            implements ExpeditionRepository {

        private final ExpeditionRepository delegate;
        private final CountDownLatch lockAttempted;

        private LockSignallingRepository(
                ExpeditionRepository delegate,
                CountDownLatch lockAttempted
        ) {
            this.delegate = delegate;
            this.lockAttempted = lockAttempted;
        }

        @Override
        public void acquireLock(String userId, String expeditionId) {
            lockAttempted.countDown();
            delegate.acquireLock(userId, expeditionId);
        }

        @Override
        public Optional<ExpeditionProgressState> findState(
                String userId,
                String expeditionId
        ) {
            return delegate.findState(userId, expeditionId);
        }

        @Override
        public void saveState(
                String userId,
                String expeditionId,
                ExpeditionProgressState state,
                Instant updatedAt
        ) {
            delegate.saveState(userId, expeditionId, state, updatedAt);
        }

        @Override
        public Optional<ProcessedExpeditionAdvance> findProcessed(
                ExpeditionIdempotencyScope scope
        ) {
            return delegate.findProcessed(scope);
        }

        @Override
        public void saveProcessed(
                ExpeditionIdempotencyScope scope,
                ProcessedExpeditionAdvance processed
        ) {
            delegate.saveProcessed(scope, processed);
        }

        @Override
        public long findJourneyNumber(String userId, String expeditionId) {
            return delegate.findJourneyNumber(userId, expeditionId);
        }

        @Override
        public void saveJourneyNumber(
                String userId,
                String expeditionId,
                long journeyNumber,
                Instant updatedAt
        ) {
            delegate.saveJourneyNumber(
                    userId,
                    expeditionId,
                    journeyNumber,
                    updatedAt
            );
        }

        @Override
        public Optional<ProcessedExpeditionJourneyStart> findProcessedJourney(
                ExpeditionIdempotencyScope scope
        ) {
            return delegate.findProcessedJourney(scope);
        }

        @Override
        public void saveProcessedJourney(
                ExpeditionIdempotencyScope scope,
                ProcessedExpeditionJourneyStart processed
        ) {
            delegate.saveProcessedJourney(scope, processed);
        }
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
