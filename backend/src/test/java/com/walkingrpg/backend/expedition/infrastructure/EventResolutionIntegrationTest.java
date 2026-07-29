package com.walkingrpg.backend.expedition.infrastructure;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import com.walkingrpg.backend.activity.application.ActivitySyncService;
import com.walkingrpg.backend.activity.domain.ActivitySyncCommand;
import com.walkingrpg.backend.expedition.application.EventResolutionIdempotencyConflictException;
import com.walkingrpg.backend.expedition.application.EventResolutionService;
import com.walkingrpg.backend.expedition.application.ExpeditionAdvanceService;
import com.walkingrpg.backend.expedition.application.StarterExpeditionContent;
import com.walkingrpg.backend.expedition.domain.EventIdempotencyScope;
import com.walkingrpg.backend.expedition.domain.EventResolutionCommand;
import com.walkingrpg.backend.expedition.domain.EventResolutionResult;
import com.walkingrpg.backend.expedition.domain.ExpeditionAdvanceCommand;
import com.walkingrpg.backend.expedition.domain.ExpeditionProgressStatus;
import com.walkingrpg.backend.expedition.domain.ProcessedEventResolution;
import com.walkingrpg.backend.home.api.HomeSnapshotResponse;
import com.walkingrpg.backend.home.application.HomeService;
import com.walkingrpg.backend.home.domain.HomeQuery;
import com.walkingrpg.backend.inventory.application.InventoryService;
import com.walkingrpg.backend.platform.api.PlatformCommandRequest;
import com.walkingrpg.backend.platform.application.PlatformService;
import com.walkingrpg.backend.progression.application.ProgressionService;
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
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;

@SpringBootTest
@ActiveProfiles("test")
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
    private PlatformService platformService;

    @Autowired
    private InventoryService inventoryService;

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
        assertEquals(2L, inventoryQuantity("lumen-shard"));
        assertEquals("IN_PROGRESS", expeditionStatus());

        HomeSnapshotResponse home = homeService.getSnapshot(
                new HomeQuery("event-user", LOCAL_DATE)
        );
        assertEquals(StarterExpeditionContent.CONTENT_VERSION, home.contentVersion());
        assertEquals(90, home.pilot().currentExperience());
        assertEquals(23, home.pet().bond());
        assertEquals("IN_PROGRESS", home.expedition().status());
        assertEquals(StarterExpeditionContent.THIRD_NODE_ID,
                home.expedition().currentNodeId());
        assertNull(home.expedition().unlockedEvent());
        assertEquals(1, home.inventory().size());
        assertEquals("lumen-shard", home.inventory().getFirst().itemId());
        assertEquals(2, home.inventory().getFirst().quantity());

        assertThrows(
                EventResolutionIdempotencyConflictException.class,
                () -> eventResolutionService.resolve(command(
                        "event-user",
                        StarterExpeditionContent.SECOND_EVENT_ID,
                        "follow-echo",
                        "resolve-second"
                ))
        );
    }

    @Test
    void shouldRollbackSecondEventInventoryProgressionAndExpeditionOnLateFailure() {
        prepareFirstEvent("rollback-event-user");
        eventResolutionService.resolve(command(
                "rollback-event-user",
                StarterExpeditionContent.FIRST_EVENT_ID,
                "analyze-signal",
                "rollback-first"
        ));
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
}
