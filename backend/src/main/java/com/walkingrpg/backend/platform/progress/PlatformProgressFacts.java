package com.walkingrpg.backend.platform.progress;

import java.util.Map;

public record PlatformProgressFacts(
        long totalAcceptedSteps,
        long resolvedEventCount,
        Map<String, Integer> petBonds,
        String squadId
) {
    public PlatformProgressFacts {
        petBonds = petBonds == null ? Map.of() : Map.copyOf(petBonds);
        if (totalAcceptedSteps < 0 || resolvedEventCount < 0
                || petBonds.values().stream().anyMatch(value -> value == null || value < 0)) {
            throw new IllegalArgumentException("Progress facts не могут быть отрицательными");
        }
    }

    public PlatformProgressFacts(
            long totalAcceptedSteps,
            long resolvedEventCount,
            int sparkBond,
            String squadId
    ) {
        this(
                totalAcceptedSteps,
                resolvedEventCount,
                Map.of("spark-v1", sparkBond),
                squadId
        );
    }

    public static PlatformProgressFacts empty() {
        return new PlatformProgressFacts(0, 0, Map.of("spark-v1", 10), null);
    }

    public boolean inSquad() {
        return squadId != null;
    }

    public int petBond(String petId, int fallback) {
        return petBonds.getOrDefault(petId, fallback);
    }
}
