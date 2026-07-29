package com.walkingrpg.backend.platform.analytics;

import java.util.List;

public enum FirstJourneyMilestone {
    JOURNEY_STARTED,
    FIRST_ACTIVITY_SYNC,
    PET_SELECTED,
    FIRST_ENERGY,
    FIRST_NODE_REACHED,
    FIRST_EVENT_RESOLVED,
    ONBOARDING_COMPLETED;

    public static List<FirstJourneyMilestone> measuredStages() {
        return List.of(
                FIRST_ACTIVITY_SYNC,
                FIRST_ENERGY,
                PET_SELECTED,
                FIRST_NODE_REACHED,
                FIRST_EVENT_RESOLVED,
                ONBOARDING_COMPLETED
        );
    }
}
