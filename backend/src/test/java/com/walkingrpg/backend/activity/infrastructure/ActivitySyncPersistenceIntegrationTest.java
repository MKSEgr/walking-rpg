package com.walkingrpg.backend.activity.infrastructure;

import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import com.walkingrpg.backend.activity.application.ActivitySyncConflictException;
import com.walkingrpg.backend.activity.application.ActivitySyncService;
import com.walkingrpg.backend.activity.domain.ActivitySyncCalculator;
import com.walkingrpg.backend.activity.domain.ActivitySyncCommand;
import com.walkingrpg.backend.activity.domain.ActivitySyncResult;
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
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

@SpringBootTest
@Testcontainers
class ActivitySyncPersistenceIntegrationTest {

    @Container
    static final PostgreSQLContainer<?> POSTGRES =
            new PostgreSQLContainer<>("postgres:17-alpine");

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
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private PlatformTransactionManager transactionManager;

    private ExecutorService executor;

    @BeforeEach
    void cleanDatabase() {
        jdbcTemplate.update("DELETE FROM processed_activity_sync");
        jdbcTemplate.update("DELETE FROM activity_sync_state");
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
    void shouldReplayPersistedResultAfterCreatingANewServiceInstance() {
        ActivitySyncCommand command = command(6_842, "persisted-key");
        ActivitySyncResult first = service.synchronize(command);

        ActivitySyncService restartedService = new ActivitySyncService(
                repository,
                new ActivitySyncCalculator(),
                Clock.fixed(first.serverTime().plusSeconds(300), ZoneOffset.UTC)
        );
        TransactionTemplate transaction = new TransactionTemplate(transactionManager);
        ActivitySyncResult replayed = transaction.execute(
                status -> restartedService.synchronize(command)
        );

        assertEquals(first, replayed);
        assertEquals(1, rowCount("processed_activity_sync"));
        assertEquals(1, rowCount("activity_sync_state"));
        assertEquals(1, rowCount("app_user"));
        assertEquals(1, rowCount("app_device"));

        ActivitySyncCommand conflicting = command(7_000, "persisted-key");
        assertThrows(
                ActivitySyncConflictException.class,
                () -> service.synchronize(conflicting)
        );
    }

    @Test
    void shouldSerializeConcurrentRequestsForTheSameDevice() throws Exception {
        executor = Executors.newFixedThreadPool(2);
        CountDownLatch ready = new CountDownLatch(2);
        CountDownLatch start = new CountDownLatch(1);

        Future<ActivitySyncResult> first = executor.submit(
                () -> synchronizedCall(ready, start, command(100, "concurrent-1"))
        );
        Future<ActivitySyncResult> second = executor.submit(
                () -> synchronizedCall(ready, start, command(200, "concurrent-2"))
        );

        ready.await(10, TimeUnit.SECONDS);
        start.countDown();

        ActivitySyncResult firstResult = first.get(20, TimeUnit.SECONDS);
        ActivitySyncResult secondResult = second.get(20, TimeUnit.SECONDS);

        assertEquals(2, firstResult.energyGranted() + secondResult.energyGranted());
        assertEquals(
                200L,
                jdbcTemplate.queryForObject(
                        "SELECT accepted_total FROM activity_sync_state",
                        Long.class
                )
        );
        assertEquals(2, rowCount("processed_activity_sync"));
    }

    private ActivitySyncResult synchronizedCall(
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

    private ActivitySyncCommand command(long authoritativeTotal, String idempotencyKey) {
        return new ActivitySyncCommand(
                "persistent-user",
                "persistent-device",
                LocalDate.of(2026, 7, 25),
                ZoneId.of("Europe/Berlin"),
                authoritativeTotal,
                List.of(),
                "cursor-1",
                idempotencyKey,
                null
        );
    }
}
