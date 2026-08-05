package com.walkingrpg.backend.expedition.application;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;

import com.walkingrpg.backend.economy.application.EconomyService;
import com.walkingrpg.backend.economy.domain.InsufficientEnergyException;
import com.walkingrpg.backend.economy.infrastructure.InMemoryEconomyRepository;
import com.walkingrpg.backend.expedition.domain.ExpeditionAdvanceCommand;
import com.walkingrpg.backend.expedition.domain.ExpeditionAdvanceResult;
import com.walkingrpg.backend.expedition.domain.ExpeditionProgressStatus;
import com.walkingrpg.backend.expedition.infrastructure.InMemoryEventResolutionRepository;
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
                new InMemoryEventResolutionRepository(),
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
    void shouldAdvancePersistedSecondNodeAndUnlockSecondEvent() {
        InMemoryExpeditionRepository repository = new InMemoryExpeditionRepository();
        repository.saveState(
                "second-node-user",
                StarterExpeditionContent.EXPEDITION_ID,
                new com.walkingrpg.backend.expedition.domain.ExpeditionProgressState(
                        0,
                        45,
                        ExpeditionProgressStatus.IN_PROGRESS,
                        StarterExpeditionContent.SECOND_NODE_ID,
                        null,
                        2
                ),
                NOW
        );
        EconomyService secondNodeEconomy = new EconomyService(
                new InMemoryEconomyRepository()
        );
        secondNodeEconomy.creditActivityEnergy(
                "second-node-user",
                45,
                "activity-second-node",
                NOW
        );
        ExpeditionAdvanceService secondNodeService = new ExpeditionAdvanceService(
                repository,
                new InMemoryEventResolutionRepository(),
                secondNodeEconomy,
                new StarterExpeditionContent(),
                Clock.fixed(NOW, ZoneOffset.UTC)
        );

        ExpeditionAdvanceResult result = secondNodeService.advance(
                new ExpeditionAdvanceCommand(
                        "second-node-user",
                        StarterExpeditionContent.EXPEDITION_ID,
                        45,
                        "advance-second-node"
                )
        );

        assertEquals(StarterExpeditionContent.SECOND_NODE_ID, result.currentNodeId());
        assertEquals("Люминовые ворота", result.currentNodeName());
        assertEquals(45, result.requiredEnergy());
        assertEquals(ExpeditionProgressStatus.EVENT_READY, result.status());
        assertEquals(StarterExpeditionContent.SECOND_EVENT_ID,
                result.unlockedEvent().eventId());
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
                new InMemoryEventResolutionRepository(),
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

    @Test
    void shouldTimestampAdvanceAfterExpeditionLock() {
        MutableClock clock = new MutableClock(NOW.minusSeconds(30));
        InMemoryExpeditionRepository repository =
                new InMemoryExpeditionRepository() {
                    @Override
                    public void acquireLock(String userId, String expeditionId) {
                        clock.set(NOW);
                    }
                };
        EconomyService orderedEconomy = new EconomyService(
                new InMemoryEconomyRepository()
        );
        orderedEconomy.creditActivityEnergy(
                "user-1",
                30,
                "activity-lock-time",
                NOW.minusSeconds(30)
        );
        ExpeditionAdvanceService orderedService = new ExpeditionAdvanceService(
                repository,
                new InMemoryEventResolutionRepository(),
                orderedEconomy,
                new StarterExpeditionContent(),
                clock
        );

        ExpeditionAdvanceResult result = orderedService.advance(
                command(10, "advance-lock-time")
        );

        assertEquals(NOW, result.serverTime());
    }

    private ExpeditionAdvanceCommand command(long energy, String key) {
        return new ExpeditionAdvanceCommand(
                "user-1",
                StarterExpeditionContent.EXPEDITION_ID,
                energy,
                key
        );
    }

    private static final class MutableClock extends Clock {
        private Instant current;
        private final ZoneId zone;

        private MutableClock(Instant current) {
            this(current, ZoneOffset.UTC);
        }

        private MutableClock(Instant current, ZoneId zone) {
            this.current = current;
            this.zone = zone;
        }

        @Override
        public ZoneId getZone() {
            return zone;
        }

        @Override
        public synchronized Clock withZone(ZoneId requestedZone) {
            return zone.equals(requestedZone)
                    ? this
                    : new MutableClock(current, requestedZone);
        }

        @Override
        public synchronized Instant instant() {
            return current;
        }

        private synchronized void set(Instant value) {
            current = value;
        }
    }
}
