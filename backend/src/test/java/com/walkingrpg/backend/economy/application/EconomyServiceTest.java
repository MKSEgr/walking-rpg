package com.walkingrpg.backend.economy.application;

import java.time.Instant;

import com.walkingrpg.backend.economy.domain.EconomyLedgerConflictException;
import com.walkingrpg.backend.economy.domain.InsufficientEnergyException;
import com.walkingrpg.backend.economy.domain.WalletSnapshot;
import com.walkingrpg.backend.economy.infrastructure.InMemoryEconomyRepository;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class EconomyServiceTest {

    private static final Instant NOW = Instant.parse("2026-07-25T12:00:00Z");

    private final EconomyService service = new EconomyService(
            new InMemoryEconomyRepository()
    );

    @Test
    void shouldCreditDebitAndReplayLedgerSources() {
        WalletSnapshot credited = service.creditActivityEnergy(
                "user-1",
                5,
                "8:device-1:sync-1",
                NOW
        );
        WalletSnapshot debited = service.debitExpeditionEnergy(
                "user-1",
                3,
                "21:starter-expedition-v1:advance-1",
                NOW.plusSeconds(10)
        );
        WalletSnapshot replayed = service.debitExpeditionEnergy(
                "user-1",
                3,
                "21:starter-expedition-v1:advance-1",
                NOW.plusSeconds(20)
        );

        assertEquals(new WalletSnapshot(5, 1), credited);
        assertEquals(new WalletSnapshot(2, 2), debited);
        assertEquals(debited, replayed);
    }

    @Test
    void shouldRejectDebitAboveBalanceWithoutChangingWallet() {
        service.creditActivityEnergy("user-1", 2, "credit-1", NOW);

        assertThrows(
                InsufficientEnergyException.class,
                () -> service.debitExpeditionEnergy(
                        "user-1",
                        3,
                        "advance-1",
                        NOW.plusSeconds(10)
                )
        );

        WalletSnapshot current = service.creditActivityEnergy(
                "user-1",
                0,
                "observe",
                NOW.plusSeconds(20)
        );
        assertEquals(new WalletSnapshot(2, 1), current);
    }

    @Test
    void shouldRejectReusedSourceForDifferentDebit() {
        service.creditActivityEnergy("user-1", 10, "credit-1", NOW);
        service.debitExpeditionEnergy("user-1", 3, "advance-1", NOW);

        assertThrows(
                EconomyLedgerConflictException.class,
                () -> service.debitExpeditionEnergy(
                        "user-1",
                        4,
                        "advance-1",
                        NOW.plusSeconds(10)
                )
        );
    }
}
