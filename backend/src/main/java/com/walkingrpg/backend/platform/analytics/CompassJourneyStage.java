package com.walkingrpg.backend.platform.analytics;

public enum CompassJourneyStage {
    RECIPE_SEEN(CompassJourneyStageSource.CLIENT_REPORTED),
    RECIPE_READY_SEEN(CompassJourneyStageSource.CLIENT_REPORTED),
    COMPASS_CRAFTED(CompassJourneyStageSource.AUTHORITATIVE),
    COMPASS_EQUIPPED(CompassJourneyStageSource.AUTHORITATIVE),
    MIRROR_DELTA_REACHED(CompassJourneyStageSource.AUTHORITATIVE),
    ROUTE_LOCKED_SEEN(CompassJourneyStageSource.CLIENT_REPORTED),
    ROUTE_AVAILABLE_SEEN(CompassJourneyStageSource.CLIENT_REPORTED),
    RESONANCE_ROUTE_CHOSEN(CompassJourneyStageSource.AUTHORITATIVE),
    RESONANCE_ROUTE_COMPLETED(CompassJourneyStageSource.AUTHORITATIVE);

    private final CompassJourneyStageSource source;

    CompassJourneyStage(CompassJourneyStageSource source) {
        this.source = source;
    }

    public CompassJourneyStageSource source() {
        return source;
    }
}
