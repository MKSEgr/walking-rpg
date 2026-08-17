package com.walkingrpg.backend.expedition.application;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.UUID;

import com.walkingrpg.backend.expedition.domain.EventIdempotencyScope;
import com.walkingrpg.backend.expedition.domain.EventPetRewardResult;
import com.walkingrpg.backend.expedition.domain.EventPilotRewardResult;
import com.walkingrpg.backend.expedition.domain.EventResolutionResult;
import com.walkingrpg.backend.expedition.domain.EventResolutionStatus;
import com.walkingrpg.backend.expedition.domain.ExpeditionJourneyCommand;
import com.walkingrpg.backend.expedition.domain.ExpeditionJourneyStartResult;
import com.walkingrpg.backend.expedition.domain.ExpeditionProgressState;
import com.walkingrpg.backend.expedition.domain.ExpeditionProgressStatus;
import com.walkingrpg.backend.expedition.domain.ProcessedEventResolution;
import com.walkingrpg.backend.expedition.infrastructure.InMemoryEventResolutionRepository;
import com.walkingrpg.backend.expedition.infrastructure.InMemoryExpeditionRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertThrows;

class ExpeditionJourneyServiceTest {

    private static final Instant NOW = Instant.parse("2026-08-17T06:00:00Z");

    private InMemoryExpeditionRepository repository;
    private InMemoryEventResolutionRepository eventRepository;
    private ExpeditionJourneyService service;

    @BeforeEach
    void setUp() {
        repository = new InMemoryExpeditionRepository();
        repository.saveState(
                "journey-user",
                StarterExpeditionContent.EXPEDITION_ID,
                new ExpeditionProgressState(
                        30,
                        30,
                        ExpeditionProgressStatus.COMPLETED,
                        StarterExpeditionContent.FIRST_NODE_ID,
                        StarterExpeditionContent.FIRST_EVENT_ID,
                        7
                ),
                NOW.minusSeconds(30)
        );
        eventRepository = new InMemoryEventResolutionRepository();
        service = new ExpeditionJourneyService(
                repository,
                eventRepository,
                new StarterExpeditionContent(),
                () -> StarterExpeditionContent.STEADY_STEP_ROUTE_CONTENT_VERSION,
                Clock.fixed(NOW, ZoneOffset.UTC)
        );
    }

    @Test
    void shouldBeginSecondJourneyAndReplayExactlyOnce() {
        ExpeditionJourneyCommand command = command(1, "journey-key");

        ExpeditionJourneyStartResult first = service.beginNextJourney(command);
        ExpeditionJourneyStartResult replay = service.beginNextJourney(command);
        ExpeditionProgressState state = repository.findState(
                "journey-user",
                StarterExpeditionContent.EXPEDITION_ID
        ).orElseThrow();

        assertSame(first, replay);
        assertEquals(2, first.journeyNumber());
        assertEquals(0, first.progressAfter());
        assertEquals(30, first.requiredEnergy());
        assertEquals(8, first.expeditionVersion());
        assertEquals(ExpeditionProgressStatus.IN_PROGRESS, first.status());
        assertEquals(StarterExpeditionContent.FIRST_NODE_ID, first.currentNodeId());
        assertEquals(2, repository.findJourneyNumber(
                "journey-user",
                StarterExpeditionContent.EXPEDITION_ID
        ));
        assertEquals(0, state.progressEnergy());
        assertEquals(8, state.version());
    }

    @Test
    void shouldRejectStaleOrNonCompletedJourney() {
        service.beginNextJourney(command(1, "journey-key"));

        ExpeditionJourneyStateConflictException stale = assertThrows(
                ExpeditionJourneyStateConflictException.class,
                () -> service.beginNextJourney(command(1, "stale-key"))
        );
        assertEquals(1, stale.expectedJourneyNumber());
        assertEquals(2, stale.currentJourneyNumber());
        assertEquals(ExpeditionProgressStatus.IN_PROGRESS, stale.status());

        ExpeditionJourneyStateConflictException active = assertThrows(
                ExpeditionJourneyStateConflictException.class,
                () -> service.beginNextJourney(command(2, "active-key"))
        );
        assertEquals(2, active.expectedJourneyNumber());
        assertEquals(2, active.currentJourneyNumber());
    }

    @Test
    void shouldRejectChangedExpectedJourneyOnSameKey() {
        service.beginNextJourney(command(1, "journey-key"));

        assertThrows(
                ExpeditionIdempotencyConflictException.class,
                () -> service.beginNextJourney(command(2, "journey-key"))
        );
    }

    @Test
    void shouldReplayBeforePendingGuardButRejectANewStart() {
        ExpeditionJourneyCommand command = command(1, "journey-key");
        ExpeditionJourneyStartResult first = service.beginNextJourney(command);
        savePendingResult();

        assertSame(first, service.beginNextJourney(command));
        assertThrows(
                PendingEventResultException.class,
                () -> service.beginNextJourney(command(2, "new-journey-key"))
        );
    }

    private void savePendingResult() {
        EventResolutionResult result = new EventResolutionResult(
                UUID.fromString("11111111-1111-1111-1111-111111111111"),
                StarterExpeditionContent.STEADY_STEP_ROUTE_CONTENT_VERSION,
                StarterExpeditionContent.EXPEDITION_ID,
                ExpeditionProgressStatus.COMPLETED,
                9,
                StarterExpeditionContent.FIRST_EVENT_ID,
                "Источник сигнала",
                EventResolutionStatus.RESOLVED,
                "analyze-signal",
                "Проанализировать сигнал",
                "Карта импульсов",
                "Пилот сохранил маршрут.",
                new EventPilotRewardResult(
                        "navigator-v1", "Навигатор", 2, 10, 30, 100, 2
                ),
                new EventPetRewardResult(
                        "spark-v1", "Искра", 2, 5, 15, 2
                ),
                null,
                true,
                null,
                NOW
        );
        eventRepository.saveProcessed(
                new EventIdempotencyScope(
                        "journey-user",
                        StarterExpeditionContent.FIRST_EVENT_ID,
                        "pending-event-key"
                ),
                new ProcessedEventResolution("a".repeat(64), result)
        );
    }

    private ExpeditionJourneyCommand command(long expected, String key) {
        return new ExpeditionJourneyCommand(
                "journey-user",
                StarterExpeditionContent.EXPEDITION_ID,
                expected,
                key
        );
    }
}
