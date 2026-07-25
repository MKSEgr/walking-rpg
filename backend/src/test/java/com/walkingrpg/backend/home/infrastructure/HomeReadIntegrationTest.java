package com.walkingrpg.backend.home.infrastructure;

import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;

import com.walkingrpg.backend.activity.application.ActivitySyncService;
import com.walkingrpg.backend.activity.domain.ActivitySyncCommand;
import com.walkingrpg.backend.expedition.application.ExpeditionAdvanceService;
import com.walkingrpg.backend.expedition.application.StarterExpeditionContent;
import com.walkingrpg.backend.expedition.domain.ExpeditionAdvanceCommand;
import com.walkingrpg.backend.home.api.HomeSnapshotResponse;
import com.walkingrpg.backend.home.application.HomeService;
import com.walkingrpg.backend.home.domain.HomeQuery;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;

@SpringBootTest
@Testcontainers
class HomeReadIntegrationTest {

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
    private HomeService homeService;

    @Autowired
    private JdbcTemplate jdbcTemplate;

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

    @Test
    void shouldReturnAcceptedStepsCurrentBalanceAndPersistentExpedition() {
        activitySyncService.synchronize(command(6_842));
        expeditionService.advance(new ExpeditionAdvanceCommand(
                "home-user",
                StarterExpeditionContent.EXPEDITION_ID,
                30,
                "home-advance-1"
        ));

        HomeSnapshotResponse snapshot = homeService.getSnapshot(
                new HomeQuery("home-user", ACTIVITY_DATE)
        );

        assertEquals(6_842, snapshot.dailySteps());
        assertEquals(38, snapshot.availableEnergy());
        assertEquals(1, snapshot.activityStateVersion());
        assertEquals(2, snapshot.economyVersion());
        assertEquals("Europe/Berlin", snapshot.timeZone());
        assertEquals("starter-v1", snapshot.contentVersion());
        assertEquals(30, snapshot.expedition().progress());
        assertEquals(1, snapshot.expedition().version());
        assertEquals("EVENT_READY", snapshot.expedition().status());
        assertNotNull(snapshot.expedition().unlockedEvent());
        assertEquals(1, rowCount("activity_sync_state"));
        assertEquals(1, rowCount("economy_wallet"));
        assertEquals(2, rowCount("economy_ledger"));
        assertEquals(1, rowCount("expedition_progress"));
    }

    @Test
    void shouldKeepWalletAndExpeditionButReturnZeroActivityForAnotherLocalDay() {
        activitySyncService.synchronize(command(6_842));
        expeditionService.advance(new ExpeditionAdvanceCommand(
                "home-user",
                StarterExpeditionContent.EXPEDITION_ID,
                20,
                "home-advance-partial"
        ));

        HomeSnapshotResponse snapshot = homeService.getSnapshot(
                new HomeQuery("home-user", ACTIVITY_DATE.plusDays(1))
        );

        assertEquals(0, snapshot.dailySteps());
        assertEquals(48, snapshot.availableEnergy());
        assertEquals(0, snapshot.activityStateVersion());
        assertEquals(2, snapshot.economyVersion());
        assertNull(snapshot.timeZone());
        assertNull(snapshot.lastActivitySyncAt());
        assertEquals(20, snapshot.expedition().progress());
        assertEquals("IN_PROGRESS", snapshot.expedition().status());
    }

    @Test
    void shouldReturnZeroStateForUnknownUserWithoutWritingAnything() {
        HomeSnapshotResponse snapshot = homeService.getSnapshot(
                new HomeQuery("unknown-user", ACTIVITY_DATE)
        );

        assertEquals(0, snapshot.dailySteps());
        assertEquals(0, snapshot.availableEnergy());
        assertEquals(0, snapshot.activityStateVersion());
        assertEquals(0, snapshot.economyVersion());
        assertEquals(0, snapshot.expedition().progress());
        assertEquals("IN_PROGRESS", snapshot.expedition().status());
        assertEquals(0, rowCount("app_user"));
        assertEquals(0, rowCount("economy_wallet"));
        assertEquals(0, rowCount("activity_sync_state"));
        assertEquals(0, rowCount("expedition_progress"));
    }

    private int rowCount(String table) {
        return jdbcTemplate.queryForObject("SELECT count(*) FROM " + table, Integer.class);
    }

    private ActivitySyncCommand command(long authoritativeTotal) {
        return new ActivitySyncCommand(
                "home-user",
                "home-device",
                ACTIVITY_DATE,
                ZoneId.of("Europe/Berlin"),
                authoritativeTotal,
                List.of(),
                "cursor-home",
                "home-sync-1",
                null
        );
    }
}
