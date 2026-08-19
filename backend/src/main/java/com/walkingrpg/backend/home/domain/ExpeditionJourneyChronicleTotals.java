package com.walkingrpg.backend.home.domain;

public record ExpeditionJourneyChronicleTotals(
        long completedJourneyCount,
        long decisionCount,
        long pilotExperienceGained,
        long petBondGained
) {
    public static ExpeditionJourneyChronicleTotals empty() {
        return new ExpeditionJourneyChronicleTotals(0, 0, 0, 0);
    }
}
