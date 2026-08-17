package com.walkingrpg.backend.expedition.infrastructure;

import com.walkingrpg.backend.testsupport.PostgresTestContainer;
import java.time.Instant;

import com.walkingrpg.backend.expedition.application.ExpeditionJourneyService;
import com.walkingrpg.backend.expedition.application.ExpeditionJourneyStateConflictException;
import com.walkingrpg.backend.expedition.application.StarterExpeditionContent;
import com.walkingrpg.backend.expedition.domain.ExpeditionJourneyCommand;
import com.walkingrpg.backend.expedition.domain.ExpeditionJourneyStartResult;
import com.walkingrpg.backend.expedition.domain.ExpeditionProgressStatus;
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
import static org.junit.jupiter.api.Assertions.assertThrows;

@SpringBootTest
@ActiveProfiles("test")
@Testcontainers
class ExpeditionJourneyIntegrationTest {

    private static final String USER_ID = "repeat-journey-user";

    @Container
    static final PostgreSQLContainer POSTGRES = PostgresTestContainer.create();

    @DynamicPropertySource
    static void configureDatabase(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        registry.add("spring.datasource.username", POSTGRES::getUsername);
        registry.add("spring.datasource.password", POSTGRES::getPassword);
    }

    @Autowired
    private ExpeditionJourneyService service;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @BeforeEach
    void seedCompletedJourney() {
        jdbcTemplate.update("DELETE FROM app_user WHERE user_id = ?", USER_ID);
        jdbcTemplate.update("""
                INSERT INTO app_user (user_id, created_at, last_seen_at)
                VALUES (?, now(), now())
                """, USER_ID);
        jdbcTemplate.update("""
                INSERT INTO expedition_progress (
                    user_id, expedition_id, current_node_id,
                    progress_energy, required_energy, status,
                    unlocked_event_id, version, created_at, updated_at
                ) VALUES (?, ?, 'first-light-causeway', 105, 105,
                          'COMPLETED', 'first-light-causeway-v1', 60,
                          now(), now())
                """, USER_ID, StarterExpeditionContent.EXPEDITION_ID);
        jdbcTemplate.update("""
                INSERT INTO pilot_progress (
                    user_id, pilot_id, level, current_experience,
                    next_level_experience, version, created_at, updated_at
                ) VALUES (?, 'navigator-v1', 7, 888, 1400, 20, now(), now())
                """, USER_ID);
        jdbcTemplate.update("""
                INSERT INTO pet_progress (
                    user_id, pet_id, level, bond, version,
                    created_at, updated_at
                ) VALUES (?, 'spark-v1', 6, 777, 19, now(), now())
                """, USER_ID);
        jdbcTemplate.update("""
                INSERT INTO inventory_stack (
                    user_id, item_id, quantity, version,
                    created_at, updated_at
                ) VALUES (?, 'echo-thread', 11, 8, now(), now())
                """, USER_ID);
    }

    @Test
    void shouldStartExactlyOneNewJourneyAndPreservePermanentProgress() {
        ExpeditionJourneyCommand command = command(1, "journey-start-key");

        ExpeditionJourneyStartResult first = service.beginNextJourney(command);
        ExpeditionJourneyStartResult replay = service.beginNextJourney(command);

        assertEquals(first, replay);
        assertEquals(2, first.journeyNumber());
        assertEquals(0, first.progressAfter());
        assertEquals(30, first.requiredEnergy());
        assertEquals(61, first.expeditionVersion());
        assertEquals(ExpeditionProgressStatus.IN_PROGRESS, first.status());
        assertEquals("outer-beacon", first.currentNodeId());
        assertEquals(2L, scalar("""
                SELECT journey_number
                FROM expedition_journey_cycle
                WHERE user_id = ? AND expedition_id = ?
                """, USER_ID, StarterExpeditionContent.EXPEDITION_ID));
        assertEquals(1, count("processed_expedition_journey_start"));
        assertEquals(888L, scalar("""
                SELECT current_experience FROM pilot_progress
                WHERE user_id = ? AND pilot_id = 'navigator-v1'
                """, USER_ID));
        assertEquals(777L, scalar("""
                SELECT bond FROM pet_progress
                WHERE user_id = ? AND pet_id = 'spark-v1'
                """, USER_ID));
        assertEquals(11L, scalar("""
                SELECT quantity FROM inventory_stack
                WHERE user_id = ? AND item_id = 'echo-thread'
                """, USER_ID));

        ExpeditionJourneyStateConflictException stale = assertThrows(
                ExpeditionJourneyStateConflictException.class,
                () -> service.beginNextJourney(command(1, "stale-key"))
        );
        assertEquals(2, stale.currentJourneyNumber());
        assertEquals(1, count("processed_expedition_journey_start"));
    }

    private ExpeditionJourneyCommand command(long expected, String key) {
        return new ExpeditionJourneyCommand(
                USER_ID,
                StarterExpeditionContent.EXPEDITION_ID,
                expected,
                key
        );
    }

    private long scalar(String sql, Object... arguments) {
        return jdbcTemplate.queryForObject(sql, Long.class, arguments);
    }

    private int count(String table) {
        return jdbcTemplate.queryForObject(
                "SELECT count(*) FROM " + table + " WHERE user_id = ?",
                Integer.class,
                USER_ID
        );
    }
}
