package com.walkingrpg.backend.home.infrastructure;

import com.walkingrpg.backend.testsupport.PostgresTestContainer;
import java.math.BigDecimal;
import java.sql.Connection;
import java.sql.Statement;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import javax.sql.DataSource;

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
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

@SpringBootTest
@ActiveProfiles("test")
@Testcontainers
class HomeReadIntegrationTest {

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
    private HomeService homeService;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private DataSource dataSource;

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

    @Test
    void shouldReturnAcceptedStepsCurrentBalanceAndPersistentExpedition() {
        activitySyncService.synchronize(command(6_842));
        expeditionService.advance(new ExpeditionAdvanceCommand(
                "home-user",
                StarterExpeditionContent.EXPEDITION_ID,
                30,
                "home-advance-1"
        ));
        jdbcTemplate.update("""
                INSERT INTO expedition_journey_cycle (
                    user_id, expedition_id, journey_number,
                    created_at, updated_at
                ) VALUES (?, ?, 3, now(), now())
                """, "home-user", StarterExpeditionContent.EXPEDITION_ID);

        HomeSnapshotResponse snapshot = homeService.getSnapshot(
                new HomeQuery("home-user", ACTIVITY_DATE)
        );

        assertEquals(6_842, snapshot.dailySteps());
        assertEquals(6_000, snapshot.dailyGoal());
        assertEquals("DEFAULT", snapshot.dailyGoalPolicy().source().name());
        assertEquals(38, snapshot.availableEnergy());
        assertEquals(1, snapshot.activityStateVersion());
        assertEquals(2, snapshot.economyVersion());
        assertEquals("Europe/Berlin", snapshot.timeZone());
        assertEquals(
                StarterExpeditionContent.LEGACY_CONTENT_VERSION,
                snapshot.contentVersion()
        );
        assertEquals(30, snapshot.expedition().progress());
        assertEquals(1, snapshot.expedition().version());
        assertEquals(3, snapshot.expedition().journeyNumber());
        assertEquals("EVENT_READY", snapshot.expedition().status());
        assertNotNull(snapshot.expedition().unlockedEvent());
        assertEquals(1, rowCount("activity_sync_state"));
        assertEquals(1, rowCount("economy_wallet"));
        assertEquals(2, rowCount("economy_ledger"));
        assertEquals(1, rowCount("expedition_progress"));
        assertEquals(1, rowCount("expedition_journey_cycle"));
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
        assertEquals(6_000, snapshot.dailyGoal());
        assertEquals("DEFAULT", snapshot.dailyGoalPolicy().source().name());
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
        assertEquals(6_000, snapshot.dailyGoal());
        assertEquals("DEFAULT", snapshot.dailyGoalPolicy().source().name());
        assertEquals(0, snapshot.availableEnergy());
        assertEquals(0, snapshot.activityStateVersion());
        assertEquals(0, snapshot.economyVersion());
        assertEquals(0, snapshot.expedition().progress());
        assertEquals("IN_PROGRESS", snapshot.expedition().status());
        assertNull(snapshot.expedition().journeyChronicle());
        assertEquals(0, rowCount("app_user"));
        assertEquals(0, rowCount("economy_wallet"));
        assertEquals(0, rowCount("activity_sync_state"));
        assertEquals(0, rowCount("expedition_progress"));
    }

    @Test
    void shouldCalculateAdaptiveGoalFromPreviousSevenLocalDaysOnly() {
        activitySyncService.synchronize(command(
                ACTIVITY_DATE.minusDays(8),
                12_000,
                "goal-outside-window"
        ));
        activitySyncService.synchronize(command(
                ACTIVITY_DATE.minusDays(7),
                3_000,
                "rhythm-before-window"
        ));
        activitySyncService.synchronize(command(
                ACTIVITY_DATE.minusDays(3),
                2_000,
                "goal-history-1"
        ));
        activitySyncService.synchronize(command(
                ACTIVITY_DATE.minusDays(2),
                3_000,
                "goal-history-2"
        ));
        activitySyncService.synchronize(command(
                ACTIVITY_DATE.minusDays(1),
                4_000,
                "goal-history-3"
        ));
        activitySyncService.synchronize(command(
                ACTIVITY_DATE,
                11_000,
                "goal-current-day"
        ));

        HomeSnapshotResponse snapshot = homeService.getSnapshot(
                new HomeQuery("home-user", ACTIVITY_DATE)
        );

        assertEquals(11_000, snapshot.dailySteps());
        assertEquals(3_250, snapshot.dailyGoal());
        assertEquals("ADAPTIVE", snapshot.dailyGoalPolicy().source().name());
        assertEquals(BigDecimal.valueOf(3_000), snapshot.dailyGoalPolicy().baselineSteps());
        assertEquals(4, snapshot.dailyGoalPolicy().sampleDays());
        assertEquals(6_000, snapshot.dailyGoalPolicy().defaultGoal());
        assertEquals(7, snapshot.dailyGoalPolicy().lookbackDays());
        assertEquals(5, snapshot.dailyGoalPolicy().growthPercent());
        assertEquals(250, snapshot.dailyGoalPolicy().roundingStep());
        assertEquals(4, snapshot.weeklyActivityRhythm().activeDays());
        assertEquals(7, snapshot.weeklyActivityRhythm().windowDays());
        assertEquals(4, snapshot.weeklyActivityRhythm().targetActiveDays());
        assertEquals(true, snapshot.weeklyActivityRhythm().targetReached());
        assertEquals(7, snapshot.weeklyActivityRhythm().days().size());
        assertEquals(ACTIVITY_DATE.minusDays(6), snapshot
                .weeklyActivityRhythm().days().getFirst().localDate());
        assertEquals(false, snapshot.weeklyActivityRhythm()
                .days().getFirst().active());
        assertEquals(true, snapshot.weeklyActivityRhythm()
                .days().get(3).active());
        assertEquals(true, snapshot.weeklyActivityRhythm()
                .days().get(4).active());
        assertEquals(true, snapshot.weeklyActivityRhythm()
                .days().get(5).active());
        assertEquals(true, snapshot.weeklyActivityRhythm()
                .days().getLast().active());
        assertEquals(ACTIVITY_DATE, snapshot.weeklyActivityRhythm()
                .days().getLast().localDate());
    }

    @Test
    void shouldProjectSelectedPetIdentityEvolutionAndLegacyFallback() {
        activitySyncService.synchronize(command(1_000));
        jdbcTemplate.update("""
                INSERT INTO roadmap_user_state (
                    user_id,
                    state_json,
                    version,
                    created_at,
                    updated_at
                )
                VALUES (?, ?::jsonb, 1, now(), now())
                """,
                "home-user",
                """
                {
                  "activePetId": "moss-v1",
                  "pets": {
                    "moss-v1": {
                      "level": 2,
                      "bond": 54,
                      "evolutionStage": 1
                    }
                  }
                }
                """
        );

        HomeSnapshotResponse snapshot = homeService.getSnapshot(
                new HomeQuery("home-user", ACTIVITY_DATE)
        );

        assertEquals("moss-v1", snapshot.pet().petId());
        assertEquals("Мох", snapshot.pet().name());
        assertEquals(2, snapshot.pet().level());
        assertEquals(54, snapshot.pet().bond());
        assertEquals(1, snapshot.pet().evolutionStage());

        jdbcTemplate.update("""
                UPDATE roadmap_user_state
                SET state_json = state_json #- '{pets,moss-v1,evolutionStage}',
                    version = version + 1,
                    updated_at = now()
                WHERE user_id = ?
                """, "home-user");

        HomeSnapshotResponse legacySnapshot = homeService.getSnapshot(
                new HomeQuery("home-user", ACTIVITY_DATE)
        );

        assertEquals("moss-v1", legacySnapshot.pet().petId());
        assertEquals(2, legacySnapshot.pet().level());
        assertEquals(54, legacySnapshot.pet().bond());
        assertEquals(0, legacySnapshot.pet().evolutionStage());
    }

    @Test
    void shouldReturnFiveRecentJourneysProvenByTheirSuccessors() {
        activitySyncService.synchronize(command(6_842));
        expeditionService.advance(new ExpeditionAdvanceCommand(
                "home-user",
                StarterExpeditionContent.EXPEDITION_ID,
                20,
                "history-current-advance"
        ));
        jdbcTemplate.update("""
                INSERT INTO expedition_journey_cycle (
                    user_id, expedition_id, journey_number,
                    created_at, updated_at
                ) VALUES (
                    ?, ?, 8,
                    TIMESTAMPTZ '2026-07-25 08:00:00+00',
                    TIMESTAMPTZ '2026-07-25 08:00:00+00'
                )
                """, "home-user", StarterExpeditionContent.EXPEDITION_ID);
        jdbcTemplate.update("""
                INSERT INTO pilot_progress (
                    user_id, pilot_id, level, current_experience,
                    next_level_experience, version, created_at, updated_at
                ) VALUES (?, 'navigator-v1', 1, 0, 100, 1, now(), now())
                """, "home-user");
        jdbcTemplate.update("""
                INSERT INTO pet_progress (
                    user_id, pet_id, level, bond, version,
                    created_at, updated_at
                ) VALUES (?, 'spark-v1', 1, 0, 1, now(), now()),
                         (?, 'moss-v1', 1, 0, 1, now(), now())
                """, "home-user", "home-user");
        jdbcTemplate.update("""
                INSERT INTO processed_expedition_journey_start (
                    user_id,
                    expedition_id,
                    idempotency_key,
                    request_fingerprint,
                    content_version,
                    expedition_name,
                    journey_number,
                    progress_after,
                    required_energy,
                    expedition_version,
                    expedition_status,
                    current_node_id,
                    current_node_name,
                    server_time,
                    created_at
                )
                SELECT ?, ?,
                       'history-start-' || journey_number,
                       repeat('a', 64),
                       'chapter-1-v11',
                       'Зов внешнего маяка',
                       journey_number,
                       0,
                       30,
                       journey_number,
                       'IN_PROGRESS',
                       'outer-beacon',
                       'Внешний маяк',
                       TIMESTAMPTZ '2026-07-25 08:00:00+00'
                               + journey_number * INTERVAL '1 hour',
                       now()
                FROM generate_series(2, 8) AS generated(journey_number)
                """, "home-user", StarterExpeditionContent.EXPEDITION_ID);
        jdbcTemplate.update("""
                INSERT INTO processed_event_resolution (
                    user_id,
                    expedition_id,
                    event_id,
                    idempotency_key,
                    request_fingerprint,
                    content_version,
                    expedition_status,
                    expedition_version,
                    event_title,
                    resolution_status,
                    choice_id,
                    choice_title,
                    outcome_title,
                    outcome_summary,
                    pilot_id,
                    pilot_name,
                    pilot_level_after,
                    pilot_experience_gained,
                    pilot_experience_after,
                    pilot_next_level_experience,
                    pilot_version,
                    pet_id,
                    pet_name,
                    pet_level_after,
                    pet_bond_gained,
                    pet_bond_after,
                    pet_version,
                    material_item_id,
                    material_item_name,
                    material_item_description,
                    material_quantity_gained,
                    material_quantity_after,
                    material_version,
                    server_time,
                    created_at,
                    journey_number
                )
                SELECT ?, ?,
                       ?,
                       'history-resolution-' || journey_number,
                       repeat('b', 64),
                       'chapter-1-v11',
                       'COMPLETED',
                       journey_number,
                       CASE WHEN journey_number <= 3
                            THEN 'Старый финал из записи'
                            WHEN journey_number <= 7
                            THEN 'Новый финал из записи'
                            ELSE 'Неподтверждённый финал'
                       END,
                       'RESOLVED',
                       CASE WHEN journey_number <= 3
                            THEN 'hold-route'
                            WHEN journey_number <= 7
                            THEN 'save-route'
                            ELSE 'open-dust'
                       END,
                       CASE WHEN journey_number <= 3
                            THEN 'Удержать маршрут'
                            WHEN journey_number <= 7
                            THEN 'Сохранить маршрут'
                            ELSE 'Открыть пыль'
                       END,
                       CASE WHEN journey_number <= 3
                            THEN 'Маршрут удержан'
                            WHEN journey_number <= 7
                            THEN 'Маршрут сохранён'
                            ELSE 'Пыль открыта'
                       END,
                       'Решение из неизменяемой истории.',
                       'navigator-v1',
                       CASE WHEN journey_number = 2
                            THEN 'Навигатор из старого похода'
                            ELSE 'Навигатор'
                       END,
                       1,
                       journey_number,
                       journey_number,
                       100,
                       journey_number,
                       CASE WHEN journey_number = 2
                            THEN 'moss-v1'
                            ELSE 'spark-v1'
                       END,
                       CASE WHEN journey_number = 2
                            THEN 'Мох из старого похода'
                            ELSE 'Искра'
                       END,
                       1,
                       journey_number,
                       journey_number,
                       journey_number,
                       CASE journey_number
                            WHEN 1 THEN 'echo-thread'
                            WHEN 2 THEN 'ash-seed'
                            WHEN 8 THEN 'unconfirmed-dust'
                       END,
                       CASE journey_number
                            WHEN 1 THEN 'Эхо-нити из старого похода'
                            WHEN 2 THEN 'Пепельное семя из старого похода'
                            WHEN 8 THEN 'Неподтверждённая пыль'
                       END,
                       CASE WHEN journey_number IN (1, 2, 8)
                            THEN 'Награда из неизменяемой истории.'
                       END,
                       CASE WHEN journey_number IN (1, 2, 8)
                            THEN journey_number
                       END,
                       CASE WHEN journey_number IN (1, 2, 8)
                            THEN journey_number
                       END,
                       CASE WHEN journey_number IN (1, 2, 8)
                            THEN journey_number
                       END,
                       TIMESTAMPTZ '2026-07-25 08:42:00+00'
                               + journey_number * INTERVAL '1 hour'
                               + CASE WHEN journey_number = 2
                                      THEN INTERVAL '1 hour'
                                      ELSE INTERVAL '0 hours'
                                 END,
                       now(),
                       journey_number
                FROM generate_series(1, 8) AS generated(journey_number)
                """,
                "home-user",
                StarterExpeditionContent.EXPEDITION_ID,
                StarterExpeditionContent.FIRST_EVENT_ID
        );

        var expedition = homeService.getSnapshot(
                new HomeQuery("home-user", ACTIVITY_DATE)
        ).expedition();

        assertNull(expedition.completionRecap());
        assertNotNull(expedition.journeyChronicle());
        assertEquals(7,
                expedition.journeyChronicle().completedJourneyCount());
        assertEquals(7, expedition.journeyChronicle().decisionCount());
        assertEquals(24_840,
                expedition.journeyChronicle().totalDurationSeconds());
        assertEquals(2_520,
                expedition.journeyChronicle().shortestDurationSeconds());
        assertEquals(3,
                expedition.journeyChronicle().shortestJourneyNumber());
        assertEquals(Instant.parse("2026-07-25T11:42:00Z"),
                expedition.journeyChronicle()
                        .shortestJourneyCompletedAt());
        assertEquals(6_120,
                expedition.journeyChronicle().longestDurationSeconds());
        assertEquals(1,
                expedition.journeyChronicle().longestJourneyNumber());
        assertEquals(Instant.parse("2026-07-25T09:42:00Z"),
                expedition.journeyChronicle()
                        .longestJourneyCompletedAt());
        assertEquals(3_548,
                expedition.journeyChronicle().averageDurationSeconds());
        assertEquals(28,
                expedition.journeyChronicle().pilotExperienceGained());
        assertEquals(2,
                expedition.journeyChronicle()
                        .pilotExperienceRewards().size());
        assertEquals("navigator-v1",
                expedition.journeyChronicle().pilotExperienceRewards()
                        .getFirst().pilotId());
        assertEquals("Навигатор",
                expedition.journeyChronicle().pilotExperienceRewards()
                        .getFirst().pilotName());
        assertEquals(26,
                expedition.journeyChronicle().pilotExperienceRewards()
                        .getFirst().experienceGained());
        assertEquals("Навигатор из старого похода",
                expedition.journeyChronicle().pilotExperienceRewards()
                        .getLast().pilotName());
        assertEquals(2,
                expedition.journeyChronicle().pilotExperienceRewards()
                        .getLast().experienceGained());
        assertEquals(28,
                expedition.journeyChronicle().petBondGained());
        assertEquals(2,
                expedition.journeyChronicle().petBondRewards().size());
        assertEquals("spark-v1",
                expedition.journeyChronicle().petBondRewards()
                        .getFirst().petId());
        assertEquals("Искра",
                expedition.journeyChronicle().petBondRewards()
                        .getFirst().petName());
        assertEquals(26,
                expedition.journeyChronicle().petBondRewards()
                        .getFirst().bondGained());
        assertEquals("moss-v1",
                expedition.journeyChronicle().petBondRewards()
                        .getLast().petId());
        assertEquals("Мох из старого похода",
                expedition.journeyChronicle().petBondRewards()
                        .getLast().petName());
        assertEquals(2,
                expedition.journeyChronicle().petBondRewards()
                        .getLast().bondGained());
        assertEquals(2,
                expedition.journeyChronicle().materials().size());
        assertEquals("echo-thread",
                expedition.journeyChronicle().materials()
                        .getFirst().itemId());
        assertEquals("Эхо-нити из старого похода",
                expedition.journeyChronicle().materials()
                        .getFirst().itemName());
        assertEquals(1,
                expedition.journeyChronicle().materials()
                        .getFirst().quantity());
        assertEquals("ash-seed",
                expedition.journeyChronicle().materials()
                        .getLast().itemId());
        assertEquals(2,
                expedition.journeyChronicle().materials()
                        .getLast().quantity());
        assertEquals(2,
                expedition.journeyChronicle().decisionOutcomes().size());
        assertEquals("Старый финал из записи",
                expedition.journeyChronicle().decisionOutcomes()
                        .getFirst().eventTitle());
        assertEquals("Удержать маршрут",
                expedition.journeyChronicle().decisionOutcomes()
                        .getFirst().choiceTitle());
        assertEquals("Маршрут удержан",
                expedition.journeyChronicle().decisionOutcomes()
                        .getFirst().outcomeTitle());
        assertEquals(3,
                expedition.journeyChronicle().decisionOutcomes()
                        .getFirst().decisionCount());
        assertEquals("Новый финал из записи",
                expedition.journeyChronicle().decisionOutcomes()
                        .getLast().eventTitle());
        assertEquals(4,
                expedition.journeyChronicle().decisionOutcomes()
                        .getLast().decisionCount());
        assertTrue(expedition.journeyChronicle().decisionOutcomes().stream()
                .noneMatch(outcome -> "Неподтверждённый финал".equals(
                        outcome.eventTitle()
                )));
        assertEquals(2,
                expedition.journeyChronicle().finaleOutcomes().size());
        assertEquals("Старый финал из записи",
                expedition.journeyChronicle().finaleOutcomes()
                        .getFirst().eventTitle());
        assertEquals("Удержать маршрут",
                expedition.journeyChronicle().finaleOutcomes()
                        .getFirst().choiceTitle());
        assertEquals("Маршрут удержан",
                expedition.journeyChronicle().finaleOutcomes()
                        .getFirst().outcomeTitle());
        assertEquals(3,
                expedition.journeyChronicle().finaleOutcomes()
                        .getFirst().journeyCount());
        assertEquals("Новый финал из записи",
                expedition.journeyChronicle().finaleOutcomes()
                        .getLast().eventTitle());
        assertEquals(4,
                expedition.journeyChronicle().finaleOutcomes()
                        .getLast().journeyCount());
        assertTrue(expedition.journeyChronicle().finaleOutcomes().stream()
                .noneMatch(outcome -> "Неподтверждённый финал".equals(
                        outcome.eventTitle()
                )));
        assertEquals(
                List.of(7L, 6L, 5L, 4L, 3L),
                expedition.recentJourneyRecaps().stream()
                        .map(recap -> recap.journeyNumber())
                        .toList()
        );
        assertEquals(
                List.of(7L, 6L, 5L, 4L, 3L),
                expedition.recentJourneyRecaps().stream()
                        .map(recap -> recap.pilotExperienceGained())
                        .toList()
        );
        assertEquals(
                List.of(7L, 6L, 5L, 4L, 3L),
                expedition.recentJourneyRecaps().stream()
                        .map(recap -> recap.pilotExperienceRewards()
                                .getFirst().experienceGained())
                        .toList()
        );
        assertTrue(expedition.recentJourneyRecaps().stream()
                .allMatch(recap -> "navigator-v1".equals(
                        recap.pilotExperienceRewards().getFirst().pilotId()
                )));
        assertTrue(expedition.recentJourneyRecaps().stream()
                .allMatch(recap -> "Навигатор".equals(
                        recap.pilotExperienceRewards().getFirst().pilotName()
                )));
        assertTrue(expedition.recentJourneyRecaps().stream()
                .allMatch(recap -> recap.materials().isEmpty()));
        assertEquals(1,
                expedition.recentJourneyRecaps().getFirst().decisionCount());
        assertTrue(expedition.recentJourneyRecaps().stream()
                .allMatch(recap -> Long.valueOf(2_520).equals(
                        recap.durationSeconds()
                )));
        assertEquals(1,
                expedition.recentJourneyRecaps().getFirst()
                        .decisions().size());
        assertEquals("Новый финал из записи",
                expedition.recentJourneyRecaps().getFirst()
                        .decisions().getFirst().eventTitle());
        assertEquals("Решение из неизменяемой истории.",
                expedition.recentJourneyRecaps().getFirst()
                        .decisions().getFirst().outcomeSummary());
        assertEquals(7,
                expedition.recentJourneyRecaps().getFirst()
                        .decisions().getFirst().pilotExperienceGained());
        assertEquals("Искра",
                expedition.recentJourneyRecaps().getFirst()
                        .decisions().getFirst().petName());
        assertEquals("Новый финал из записи",
                expedition.recentJourneyRecaps().getFirst()
                        .finalDecision().eventTitle());
        assertEquals("Сохранить маршрут",
                expedition.recentJourneyRecaps().getFirst()
                        .finalDecision().choiceTitle());
        assertEquals("Маршрут сохранён",
                expedition.recentJourneyRecaps().getFirst()
                        .finalDecision().outcomeTitle());
        assertEquals("spark-v1",
                expedition.recentJourneyRecaps().getFirst()
                        .petBondRewards().getFirst().petId());
        assertEquals("Искра",
                expedition.recentJourneyRecaps().getFirst()
                        .petBondRewards().getFirst().petName());
        assertEquals(7,
                expedition.recentJourneyRecaps().getFirst()
                        .petBondRewards().getFirst().bondGained());

        jdbcTemplate.update("""
                UPDATE processed_expedition_journey_start
                SET server_time = TIMESTAMPTZ '2026-07-25 13:00:00+00'
                WHERE user_id = ?
                  AND expedition_id = ?
                  AND journey_number = 4
                """, "home-user", StarterExpeditionContent.EXPEDITION_ID);

        var incompleteDuration = homeService.getSnapshot(
                new HomeQuery("home-user", ACTIVITY_DATE)
        ).expedition().journeyChronicle();

        assertNotNull(incompleteDuration);
        assertEquals(7, incompleteDuration.completedJourneyCount());
        assertNull(incompleteDuration.totalDurationSeconds());
        assertNull(incompleteDuration.shortestDurationSeconds());
        assertNull(incompleteDuration.shortestJourneyNumber());
        assertNull(incompleteDuration.shortestJourneyCompletedAt());
        assertNull(incompleteDuration.longestDurationSeconds());
        assertNull(incompleteDuration.longestJourneyNumber());
        assertNull(incompleteDuration.longestJourneyCompletedAt());
        assertNull(incompleteDuration.averageDurationSeconds());
    }

    @Test
    void shouldAnchorHomeServerTimeToFirstDatabaseSnapshotStatement()
            throws Exception {
        jdbcTemplate.update("""
                INSERT INTO app_user (user_id, created_at, last_seen_at)
                VALUES ('home-user', now(), now())
                """);

        HomeSnapshotResponse duringConcurrentSync;
        Instant observationStartedAt;
        Instant firstStatementFinishedAt;
        ExecutorService executor = Executors.newSingleThreadExecutor();
        Future<HomeSnapshotResponse> pending = null;
        try (Connection blocker = dataSource.getConnection();
             Statement statement = blocker.createStatement()) {
            try {
                blocker.setAutoCommit(false);
                statement.execute(
                        "LOCK TABLE processed_event_resolution "
                                + "IN ACCESS EXCLUSIVE MODE"
                );

                observationStartedAt = databaseTime();
                pending = executor.submit(() -> homeService.getSnapshot(
                        new HomeQuery("home-user", ACTIVITY_DATE)
                ));
                awaitBlockedQuery("FROM processed_event_resolution");
                firstStatementFinishedAt = databaseTime();

                // Home reads intentionally hold the account-deletion guard lock.
                // Commit the persistence fact directly so this test isolates the
                // REPEATABLE READ boundary instead of deadlocking two services.
                statement.executeUpdate("""
                        INSERT INTO activity_sync_state (
                            user_id,
                            local_date,
                            accepted_total,
                            state_version,
                            time_zone,
                            updated_at
                        ) VALUES (
                            'home-user',
                            DATE '2026-07-25',
                            1000,
                            1,
                            'Europe/Berlin',
                            statement_timestamp()
                        )
                        """);
                blocker.commit();
                duringConcurrentSync = pending.get(5, TimeUnit.SECONDS);
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

        assertEquals(0, duringConcurrentSync.dailySteps());
        assertSnapshotBoundary(
                observationStartedAt,
                duringConcurrentSync.serverTime(),
                firstStatementFinishedAt
        );
        assertEquals(
                1_000,
                homeService.getSnapshot(
                        new HomeQuery("home-user", ACTIVITY_DATE)
                ).dailySteps()
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
            Instant serverTime,
            Instant latest
    ) {
        assertFalse(serverTime.isBefore(earliest));
        assertFalse(serverTime.isAfter(latest));
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

    private int rowCount(String table) {
        return jdbcTemplate.queryForObject("SELECT count(*) FROM " + table, Integer.class);
    }

    private ActivitySyncCommand command(long authoritativeTotal) {
        return command(ACTIVITY_DATE, authoritativeTotal, "home-sync-1");
    }

    private ActivitySyncCommand command(
            LocalDate localDate,
            long authoritativeTotal,
            String idempotencyKey
    ) {
        return new ActivitySyncCommand(
                "home-user",
                "home-device",
                localDate,
                ZoneId.of("Europe/Berlin"),
                authoritativeTotal,
                List.of(),
                "cursor-" + localDate,
                idempotencyKey,
                null
        );
    }
}
