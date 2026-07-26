package com.walkingrpg.backend.expedition.application;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;

import com.walkingrpg.backend.expedition.domain.EventResolutionCommand;
import com.walkingrpg.backend.expedition.domain.EventResolutionResult;
import com.walkingrpg.backend.expedition.domain.ExpeditionProgressState;
import com.walkingrpg.backend.expedition.domain.ExpeditionProgressStatus;
import com.walkingrpg.backend.expedition.infrastructure.InMemoryEventResolutionRepository;
import com.walkingrpg.backend.expedition.infrastructure.InMemoryExpeditionRepository;
import com.walkingrpg.backend.progression.application.ProgressionService;
import com.walkingrpg.backend.progression.application.StarterProgressionContent;
import com.walkingrpg.backend.progression.infrastructure.InMemoryProgressionRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertThrows;

class EventResolutionServiceTest {

    private static final Instant NOW = Instant.parse("2026-07-26T06:00:00Z");

    private InMemoryExpeditionRepository expeditionRepository;
    private EventResolutionService service;

    @BeforeEach
    void setUp() {
        StarterExpeditionContent content = new StarterExpeditionContent();
        expeditionRepository = new InMemoryExpeditionRepository();
        expeditionRepository.saveState(
                "user-1",
                StarterExpeditionContent.EXPEDITION_ID,
                readyState(),
                NOW
        );
        service = new EventResolutionService(
                expeditionRepository,
                new InMemoryEventResolutionRepository(),
                new ProgressionService(
                        new InMemoryProgressionRepository(),
                        new StarterProgressionContent()
                ),
                content,
                Clock.fixed(NOW, ZoneOffset.UTC)
        );
    }

    @Test
    void shouldResolveAnalyzeChoiceAndReplayExactResult() {
        EventResolutionCommand command = command("analyze-signal", "resolve-1");

        EventResolutionResult first = service.resolve(command);
        EventResolutionResult replayed = service.resolve(command);

        assertSame(first, replayed);
        assertEquals(ExpeditionProgressStatus.COMPLETED, first.expeditionStatus());
        assertEquals(2, first.expeditionVersion());
        assertEquals(40, first.pilot().experienceGained());
        assertEquals(60, first.pilot().currentExperience());
        assertEquals(5, first.pet().bondGained());
        assertEquals(15, first.pet().bond());
        assertEquals("Карта импульсов", first.outcomeTitle());
    }

    @Test
    void shouldUseDifferentRewardForTrustSparkChoice() {
        EventResolutionResult result = service.resolve(
                command("trust-spark", "resolve-trust")
        );

        assertEquals(20, result.pilot().experienceGained());
        assertEquals(40, result.pilot().currentExperience());
        assertEquals(15, result.pet().bondGained());
        assertEquals(25, result.pet().bond());
        assertEquals("След Люмина", result.outcomeTitle());
    }

    @Test
    void shouldRejectReusedKeyWithDifferentChoice() {
        service.resolve(command("analyze-signal", "same-key"));

        assertThrows(
                EventResolutionIdempotencyConflictException.class,
                () -> service.resolve(command("trust-spark", "same-key"))
        );
    }

    @Test
    void shouldRejectSecondResolutionWithAnotherKey() {
        service.resolve(command("analyze-signal", "first-key"));

        EventStateConflictException exception = assertThrows(
                EventStateConflictException.class,
                () -> service.resolve(command("analyze-signal", "second-key"))
        );
        assertEquals("COMPLETED", exception.status());
    }

    @Test
    void shouldRejectUnknownChoice() {
        assertThrows(
                EventResolutionValidationException.class,
                () -> service.resolve(command("unknown-choice", "unknown-key"))
        );
    }

    private EventResolutionCommand command(String choiceId, String key) {
        return new EventResolutionCommand(
                "user-1",
                StarterExpeditionContent.EVENT_ID,
                choiceId,
                key
        );
    }

    private ExpeditionProgressState readyState() {
        return new ExpeditionProgressState(
                30,
                30,
                ExpeditionProgressStatus.EVENT_READY,
                "outer-beacon",
                StarterExpeditionContent.EVENT_ID,
                1
        );
    }
}
