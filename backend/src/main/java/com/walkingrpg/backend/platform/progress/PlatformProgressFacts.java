package com.walkingrpg.backend.platform.progress;

public record PlatformProgressFacts(
        long totalAcceptedSteps,
        long resolvedEventCount,
        int sparkBond,
        String squadId
) {
    public PlatformProgressFacts {
        if (totalAcceptedSteps < 0 || resolvedEventCount < 0 || sparkBond < 0) {
            throw new IllegalArgumentException("Progress facts не могут быть отрицательными");
        }
    }

    public static PlatformProgressFacts empty() {
        return new PlatformProgressFacts(0, 0, 10, null);
    }

    public boolean inSquad() {
        return squadId != null;
    }
}
