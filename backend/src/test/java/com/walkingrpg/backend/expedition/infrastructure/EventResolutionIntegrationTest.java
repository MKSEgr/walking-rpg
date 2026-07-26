package com.walkingrpg.backend.expedition.infrastructure;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;

import com.walkingrpg.backend.activity.application.ActivitySyncService;
import com.walkingrpg.backend.activity.domain.ActivitySyncCommand;
import com.walkingrpg.backend.expedition.application.EventResolutionIdempotencyConflictException;
import com.walkingrpg.backend.expedition.application.EventResolutionService;
import com.walkingrpg.backend.expedition.application.StarterExpeditionContent;
import com.walkingrpg.backend.expedition.domain.EventIdempotencyScope;
import com.walkingrpg.backend.expedition.domain.EventResolutionCommand;
import com.walkingrpg.backend.expedition.domain.EventResolutionResult;
import com.walkingrpg.backend.expedition.domain.ExpeditionAdvanceCommand;
import com.walkingrpg.backend.expedition.domain.ExpeditionProgressStatus;
import com.walkingrpg.backend.expedition.domain.ProcessedEventResolution;
import com.walkingrpg.backend.expedition.application.ExpeditionAdvanceService;
import com.walkingrpg.backend.home.api.HomeSnapshotResponse;
import com.walkingrpg.backend.home.application.HomeService;
import com.walkingrpg.backend.home.domain.HomeQuery;
import com.walkingrpg.backend.progression.application.ProgressionService;
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
class EventResolutionIntegrationTest {

    private static final LocalDate LOCAL_DATE = LocalDate.of(2026, 7, 26);
    private static final Instant NOW = Instant.parse("2026-07-26T06:00:00Z");

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
    private StarterExpeditionContent content;

    @Autowired
    private HomeService homeService;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private PlatformTransactionManager transactionManager;

    @BeforeEach
    void cleanDatabase() {
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
    }

    @Test
    void shouldResolveEventPersistRewardsReplayAndExposeHomeOutcome() {
        prepareReadyEvent("event-user");
        EventResolutionCommand command = command(
                "event-user",
                "analyze-signal",
                "resolve-persisted-1"
        );

        EventResolutionResult first = eventResolutionService.resolve(command);
        EventResolutionService restarted = new EventResolutionService(
                expeditionRepository,
                eventResolutionRepository,
                progressionService,
                content,
                Clock.fixed(NOW.plusSeconds(300), ZoneOffset.UTC)
        );
        TransactionTemplate transaction = new TransactionTemplate(transactionManager);
        EventResolutionResult replayed = transaction.execute(
                status -> restarted.resolve(command)
        );

        assertEquals(first, replayed);
        assertEquals(ExpeditionProgressStatus.COMPLETED, first.expeditionStatus());
        assertEquals(60, pilotExperience());
        assertEquals(15, petBond());
        assertEquals(38, walletBalance());
        assertEquals(1, rowCount("processed_event_resolution"));
        assertEquals(1, rowCount("pilot_progress"));
        assertEquals(1, rowCount("pet_progress"));
        assertEquals("COMPLETED", expeditionStatus());

        HomeSnapshotResponse home = homeService.getSnapshot(
                new HomeQuery("event-user", LOCAL_DATE)
        );
        assertEquals(60, home.pilot().currentExperience());
        assertEquals(15, home.pet().bond());
        assertEquals("COMPLETED", home.expedition().status());
        assertNotNull(home.expedition().unlockedEvent());
        assertEquals("RESOLVED", home.expedition().unlockedEvent().status());
        assertEquals(
                "analyze-signal",
                home.expedition().unlockedEvent().selectedChoiceId()
        );
        assertEquals(2, home.expedition().unlockedEvent().choices().size());

        assertThrows(
                EventResolutionIdempotencyConflictException.class,
                () -> eventResolutionService.resolve(command(
                        "event-user",
                        "trust-spark",
                        "resolve-persisted-1"
                ))
        );
    }

    @Test
    void shouldRollbackExpeditionAndProgressionWhenProcessedSaveFails() {
        prepareReadyEvent("rollback-event-user");
        EventResolutionRepository failingRepository = new EventResolutionRepository() {
            @Override
            public Optional<ProcessedEventResolution> findProcessed(
                    EventIdempotencyScope scope
            ) {
                return eventResolutionRepository.findProcessed(scope);
            }

            @Override
            public void saveProcessed(
                    EventIdempotencyScope scope,
                    ProcessedEventResolution processed
            ) {
                throw new IllegalStateException("forced processed event failure");
            }
        };
        EventResolutionService failingService = new EventResolutionService(
                expeditionRepository,
                failingRepository,
                progressionService,
                content,
                Clock.fixed(NOW, ZoneOffset.UTC)
        );
        TransactionTemplate transaction = new TransactionTemplate(transactionManager);

        assertThrows(
                IllegalStateException.class,
                () -> transaction.executeWithoutResult(status -> failingService.resolve(
                        command("rollback-event-user", "analyze-signal", "rollback-key")
                ))
        );

        assertEquals("EVENT_READY", expeditionStatus());
        assertEquals(0, rowCount("processed_event_resolution"));
        assertEquals(0, rowCount("pilot_progress"));
        assertEquals(0, rowCount("pet_progress"));
        assertEquals(38, walletBalance());
    }

    private void prepareReadyEvent(String userId) {
        activitySyncService.synchronize(new ActivitySyncCommand(
                userId,
                "event-device",
                LOCAL_DATE,
                ZoneId.of("Europe/Berlin"),
                6_842,
                List.of(),
                "event-cursor",
                "activity-" + userId,
                null
        ));
        expeditionAdvanceService.advance(new ExpeditionAdvanceCommand(
                userId,
                StarterExpeditionContent.EXPEDITION_ID,
                30,
                "advance-" + userId
        ));
    }

    private EventResolutionCommand command(
            String userId,
            String choiceId,
            String idempotencyKey
    ) {
        return new EventResolutionCommand(
                userId,
                StarterExpeditionContent.EVENT_ID,
                choiceId,
                idempotencyKey
        );
    }

    private int rowCount(String table) {
        return jdbcTemplate.queryForObject("SELECT count(*) FROM " + table, Integer.class);
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

    private String expeditionStatus() {
        return jdbcTemplate.queryForObject(
                "SELECT status FROM expedition_progress",
                String.class
        );
    }
}
