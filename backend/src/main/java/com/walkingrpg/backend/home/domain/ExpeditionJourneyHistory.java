package com.walkingrpg.backend.home.domain;

import java.time.Instant;
import java.util.List;

public record ExpeditionJourneyHistory(
        long journeyNumber,
        Instant startedAt,
        List<ExpeditionJourneyEvent> events
) {
    public ExpeditionJourneyHistory {
        if (journeyNumber <= 0) {
            throw new IllegalArgumentException(
                    "Номер завершённого похода должен быть положительным"
            );
        }
        events = events == null ? List.of() : List.copyOf(events);
    }

    public ExpeditionJourneyHistory(
            long journeyNumber,
            List<ExpeditionJourneyEvent> events
    ) {
        this(journeyNumber, null, events);
    }
}
