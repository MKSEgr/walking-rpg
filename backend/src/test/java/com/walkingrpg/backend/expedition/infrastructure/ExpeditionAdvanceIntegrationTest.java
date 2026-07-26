package com.walkingrpg.backend.expedition.infrastructure;

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
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
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

@SpringBootTest
@Testcontainers
class ExpeditionAdvanceIntegrationTest {

    private static final LocalDate ACTIVITY_DATE = LocalDate.of(2026, 7, 25);

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
    private ActivitySyncService activitySyncService;

    @Autowired
    private ExpeditionAdvanceService expeditionService;

    @Autowired
    private ExpeditionRepository expeditionRepository;

    @Autowired
    private EconomyService economyService;

    @Autowired
    private StarterExpeditionContent content;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private PlatformTransactionManager transactionManager;

    private ExecutorService executor;

    @BeforeEach
    void cleanDatabase() {
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
    void shouldRollbackDebitAndProgressWhenProcessedResponseSaveFails() {
        seedEnergy("rollback-user", "device-rollback", 6_000, "sync-rollback");
        ExpeditionRepository failingRepository = new FailingProcessedSaveRepository(
                expeditionRepository
        );
        ExpeditionAdvanceService failingService = new ExpeditionAdvanceService(
                failingRepository,
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
    }
}
