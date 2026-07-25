package com.walkingrpg.backend.economy.application;

import java.time.Instant;

import com.walkingrpg.backend.economy.domain.EconomyLedgerConflictException;
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
    void shouldCreditEnergyAndReplaySameLedgerSource() {
        WalletSnapshot first = service.creditActivityEnergy(
                "user-1",
                2,
                "8:device-1:sync-1",
                NOW
        );
        WalletSnapshot replayed = service.creditActivityEnergy(
                "user-1",
                2,
                "8:device-1:sync-1",
                NOW.plusSeconds(10)
        );
        WalletSnapshot second = service.creditActivityEnergy(
                "user-1",
                1,
                "8:device-1:sync-2",
                NOW.plusSeconds(20)
        );

        assertEquals(new WalletSnapshot(2, 1), first);
        assertEquals(first, replayed);
        assertEquals(new WalletSnapshot(3, 2), second);
    }

    @Test
    void shouldNotCreateLedgerVersionForZeroCredit() {
        WalletSnapshot snapshot = service.creditActivityEnergy(
                "user-1",
                0,
                "8:device-1:no-threshold",
                NOW
        );

        assertEquals(new WalletSnapshot(0, 0), snapshot);
    }

    @Test
    void shouldRejectReusedLedgerSourceForDifferentAmount() {
        service.creditActivityEnergy(
                "user-1",
                2,
                "8:device-1:sync-1",
                NOW
        );

        assertThrows(
                EconomyLedgerConflictException.class,
                () -> service.creditActivityEnergy(
                        "user-1",
                        3,
                        "8:device-1:sync-1",
                        NOW.plusSeconds(10)
                )
        );
    }
}
