package com.walkingrpg.backend.activity.infrastructure;

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

import com.walkingrpg.backend.activity.application.ActivitySyncConflictException;
import com.walkingrpg.backend.activity.application.ActivitySyncService;
import com.walkingrpg.backend.activity.domain.ActivityDayKey;
import com.walkingrpg.backend.activity.domain.ActivityDayState;
import com.walkingrpg.backend.activity.domain.ActivitySyncCalculator;
import com.walkingrpg.backend.activity.domain.ActivitySyncCommand;
import com.walkingrpg.backend.activity.domain.ActivitySyncOutcome;
import com.walkingrpg.backend.activity.domain.IdempotencyScope;
import com.walkingrpg.backend.activity.domain.ProcessedActivitySync;
import com.walkingrpg.backend.economy.application.EconomyService;
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
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

@SpringBootTest
@Testcontainers
class ActivitySyncPersistenceIntegrationTest {

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
    private ActivitySyncService service;

    @Autowired
    private ActivitySyncRepository repository;

    @Autowired
    private EconomyService economyService;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private PlatformTransactionManager transactionManager;

    private ExecutorService executor;

    @BeforeEach
    void cleanDatabase() {
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
    void shouldReplayPersistedOutcomeAfterCreatingANewServiceInstance() {
        ActivitySyncCommand command = command("persistent-device", 6_842, "persisted-key");
        ActivitySyncOutcome first = service.synchronize(command);

        ActivitySyncService restartedService = new ActivitySyncService(
                repository,
                new ActivitySyncCalculator(),
                economyService,
                Clock.fixed(first.activity().serverTime().plusSeconds(300), ZoneOffset.UTC)
        );
        TransactionTemplate transaction = new TransactionTemplate(transactionManager);
        ActivitySyncOutcome replayed = transaction.execute(
                status -> restartedService.synchronize(command)
        );

        assertEquals(first, replayed);
        assertEquals(68, first.energyBalanceAfter());
        assertEquals(1, first.economyVersion());
        assertEquals(1, rowCount("processed_activity_sync"));
        assertEquals(1, rowCount("activity_sync_state"));
        assertEquals(1, rowCount("economy_wallet"));
        assertEquals(1, rowCount("economy_ledger"));
        assertEquals(68L, walletBalance());
        assertEquals(68L, ledgerAmountSum());
        assertEquals(1, rowCount("app_user"));
        assertEquals(1, rowCount("app_device"));

        ActivitySyncCommand conflicting = command("persistent-device", 7_000, "persisted-key");
        assertThrows(
                ActivitySyncConflictException.class,
                () -> service.synchronize(conflicting)
        );
    }

    @Test
    void shouldOnlyAppendLedgerWhenEnergyThresholdIsCrossed() {
        ActivitySyncOutcome belowThreshold = service.synchronize(
                command("threshold-device", 99, "threshold-1")
        );
        ActivitySyncOutcome crossedThreshold = service.synchronize(
                command("threshold-device", 100, "threshold-2")
        );
        ActivitySyncOutcome noChange = service.synchronize(
                command("threshold-device", 100, "threshold-3")
        );
        ActivitySyncOutcome decreased = service.synchronize(
                command("threshold-device", 90, "threshold-4")
        );

        assertEquals(0, belowThreshold.energyBalanceAfter());
        assertEquals(0, belowThreshold.economyVersion());
        assertEquals(1, crossedThreshold.energyBalanceAfter());
        assertEquals(1, crossedThreshold.economyVersion());
        assertEquals(1, noChange.energyBalanceAfter());
        assertEquals(1, noChange.economyVersion());
        assertEquals(1, decreased.energyBalanceAfter());
        assertEquals(1, decreased.economyVersion());
        assertEquals(1, rowCount("economy_ledger"));
        assertEquals(1L, walletBalance());
    }

    @Test
    void shouldSerializeConcurrentRequestsAcrossDevicesForSameUser() throws Exception {
        executor = Executors.newFixedThreadPool(2);
        CountDownLatch ready = new CountDownLatch(2);
        CountDownLatch start = new CountDownLatch(1);

        Future<ActivitySyncOutcome> first = executor.submit(
                () -> synchronizedCall(ready, start, command("device-a", 100, "concurrent-1"))
        );
        Future<ActivitySyncOutcome> second = executor.submit(
                () -> synchronizedCall(ready, start, command("device-b", 200, "concurrent-2"))
        );

        ready.await(10, TimeUnit.SECONDS);
        start.countDown();

        ActivitySyncOutcome firstOutcome = first.get(20, TimeUnit.SECONDS);
        ActivitySyncOutcome secondOutcome = second.get(20, TimeUnit.SECONDS);

        assertEquals(
                2,
                firstOutcome.activity().energyGranted()
                        + secondOutcome.activity().energyGranted()
        );
        assertEquals(200L, acceptedTotal());
        assertEquals(2L, walletBalance());
        assertEquals(2L, ledgerAmountSum());
        assertTrue(rowCount("economy_ledger") >= 1);
        assertTrue(rowCount("economy_ledger") <= 2);
        assertEquals(2, rowCount("processed_activity_sync"));
        assertEquals(1, rowCount("activity_sync_state"));
        assertEquals(1, rowCount("economy_wallet"));
        assertEquals(2, rowCount("app_device"));
    }

    @Test
    void shouldRollbackWalletLedgerStateAndIdentityWhenProcessedSaveFails() {
        ActivitySyncRepository failingRepository = new FailingProcessedSaveRepository(repository);
        ActivitySyncService failingService = new ActivitySyncService(
                failingRepository,
                new ActivitySyncCalculator(),
                economyService,
                Clock.fixed(Instant.parse("2026-07-25T12:00:00Z"), ZoneOffset.UTC)
        );
        TransactionTemplate transaction = new TransactionTemplate(transactionManager);

        assertThrows(
                IllegalStateException.class,
                () -> transaction.executeWithoutResult(
                        status -> failingService.synchronize(
                                command("rollback-device", 250, "rollback-key")
                        )
                )
        );

        assertEquals(0, rowCount("processed_activity_sync"));
        assertEquals(0, rowCount("economy_ledger"));
        assertEquals(0, rowCount("activity_sync_state"));
        assertEquals(0, rowCount("economy_wallet"));
        assertEquals(0, rowCount("app_device"));
        assertEquals(0, rowCount("app_user"));
    }

    private ActivitySyncOutcome synchronizedCall(
            CountDownLatch ready,
            CountDownLatch start,
            ActivitySyncCommand command
    ) throws InterruptedException {
        ready.countDown();
        start.await(10, TimeUnit.SECONDS);
        return service.synchronize(command);
    }

    private int rowCount(String table) {
        return jdbcTemplate.queryForObject("SELECT count(*) FROM " + table, Integer.class);
    }

    private long acceptedTotal() {
        return jdbcTemplate.queryForObject(
                "SELECT accepted_total FROM activity_sync_state",
                Long.class
        );
    }

    private long walletBalance() {
        return jdbcTemplate.queryForObject(
                "SELECT balance FROM economy_wallet WHERE currency_code = 'ENERGY'",
                Long.class
        );
    }

    private long ledgerAmountSum() {
        Long value = jdbcTemplate.queryForObject(
                "SELECT COALESCE(sum(amount), 0) FROM economy_ledger",
                Long.class
        );
        return value == null ? 0 : value;
    }

    private ActivitySyncCommand command(
            String deviceId,
            long authoritativeTotal,
            String idempotencyKey
    ) {
        return new ActivitySyncCommand(
                "persistent-user",
                deviceId,
                LocalDate.of(2026, 7, 25),
                ZoneId.of("Europe/Berlin"),
                authoritativeTotal,
                List.of(),
                "cursor-1",
                idempotencyKey,
                null
        );
    }

    private static final class FailingProcessedSaveRepository
            implements ActivitySyncRepository {

        private final ActivitySyncRepository delegate;

        private FailingProcessedSaveRepository(ActivitySyncRepository delegate) {
            this.delegate = delegate;
        }

        @Override
        public void acquireUserLock(String userId) {
            delegate.acquireUserLock(userId);
        }

        @Override
        public void registerDevice(String userId, String deviceId, Instant seenAt) {
            delegate.registerDevice(userId, deviceId, seenAt);
        }

        @Override
        public Optional<ActivityDayState> findState(ActivityDayKey key) {
            return delegate.findState(key);
        }

        @Override
        public void saveState(ActivityDayKey key, ActivityDayState state, ZoneId timeZone) {
            delegate.saveState(key, state, timeZone);
        }

        @Override
        public Optional<ProcessedActivitySync> findProcessed(IdempotencyScope scope) {
            return delegate.findProcessed(scope);
        }

        @Override
        public void saveProcessed(
                IdempotencyScope scope,
                ProcessedActivitySync processedSync
        ) {
            throw new IllegalStateException("forced processed response failure");
        }
    }
}
