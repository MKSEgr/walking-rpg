package com.walkingrpg.backend.home.domain;

public record ExpeditionJourneyChronicleSnapshot(
        long completedJourneyCount,
        long decisionCount,
        long pilotExperienceGained,
        long petBondGained
) {
}
