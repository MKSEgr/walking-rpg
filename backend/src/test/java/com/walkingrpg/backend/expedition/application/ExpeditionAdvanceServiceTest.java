package com.walkingrpg.backend.expedition.application;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;

import com.walkingrpg.backend.economy.application.EconomyService;
import com.walkingrpg.backend.economy.domain.InsufficientEnergyException;
import com.walkingrpg.backend.economy.infrastructure.InMemoryEconomyRepository;
import com.walkingrpg.backend.expedition.domain.ExpeditionAdvanceCommand;
import com.walkingrpg.backend.expedition.domain.ExpeditionAdvanceResult;
import com.walkingrpg.backend.expedition.domain.ExpeditionProgressStatus;
import com.walkingrpg.backend.expedition.infrastructure.InMemoryExpeditionRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertThrows;

class ExpeditionAdvanceServiceTest {

    private static final Instant NOW = Instant.parse("2026-07-25T12:00:00Z");

    private EconomyService economyService;
    private ExpeditionAdvanceService service;

    @BeforeEach
    void setUp() {
        economyService = new EconomyService(new InMemoryEconomyRepository());
        service = new ExpeditionAdvanceService(
                new InMemoryExpeditionRepository(),
                economyService,
                new StarterExpeditionContent(),
                Clock.fixed(NOW, ZoneOffset.UTC)
        );
        economyService.creditActivityEnergy("user-1", 68, "activity-1", NOW);
    }

    @Test
    void shouldAdvancePartiallyThenUnlockEvent() {
        ExpeditionAdvanceResult partial = service.advance(command(20, "advance-1"));
        ExpeditionAdvanceResult completed = service.advance(command(10, "advance-2"));

        assertEquals(20, partial.progressAfter());
        assertEquals(48, partial.energyBalanceAfter());
        assertEquals(ExpeditionProgressStatus.IN_PROGRESS, partial.status());
        assertEquals(30, completed.progressAfter());
        assertEquals(38, completed.energyBalanceAfter());
        assertEquals(ExpeditionProgressStatus.EVENT_READY, completed.status());
        assertNotNull(completed.unlockedEvent());
        assertEquals("signal-source-v1", completed.unlockedEvent().eventId());
    }

    @Test
    void shouldReplaySameResultAndRejectChangedPayload() {
        ExpeditionAdvanceCommand original = command(10, "same-key");
        ExpeditionAdvanceResult first = service.advance(original);
        ExpeditionAdvanceResult replayed = service.advance(original);

        assertSame(first, replayed);
        assertThrows(
                ExpeditionIdempotencyConflictException.class,
                () -> service.advance(command(11, "same-key"))
        );
    }

    @Test
    void shouldRejectInsufficientEnergyWithoutProgress() {
        EconomyService poorEconomy = new EconomyService(new InMemoryEconomyRepository());
        poorEconomy.creditActivityEnergy("poor-user", 5, "activity-poor", NOW);
        ExpeditionAdvanceService poorService = new ExpeditionAdvanceService(
                new InMemoryExpeditionRepository(),
                poorEconomy,
                new StarterExpeditionContent(),
                Clock.fixed(NOW, ZoneOffset.UTC)
        );

        assertThrows(
                InsufficientEnergyException.class,
                () -> poorService.advance(new ExpeditionAdvanceCommand(
                        "poor-user",
                        StarterExpeditionContent.EXPEDITION_ID,
                        10,
                        "poor-advance"
                ))
        );
    }

    @Test
    void shouldRejectAmountAboveRemainingAndFurtherAdvanceAfterEvent() {
        service.advance(command(20, "advance-1"));

        assertThrows(
                ExpeditionStateConflictException.class,
                () -> service.advance(command(11, "advance-too-far"))
        );

        service.advance(command(10, "advance-2"));
        assertThrows(
                ExpeditionStateConflictException.class,
                () -> service.advance(command(1, "advance-after-event"))
        );
    }

    private ExpeditionAdvanceCommand command(long energy, String key) {
        return new ExpeditionAdvanceCommand(
                "user-1",
                StarterExpeditionContent.EXPEDITION_ID,
                energy,
                key
        );
    }
}
