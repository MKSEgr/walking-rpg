package com.walkingrpg.backend.home.domain;

import java.util.List;

public record ExpeditionEventSnapshot(
        String eventId,
        String title,
        String summary,
        String status,
        List<ExpeditionEventChoiceSnapshot> choices,
        String selectedChoiceId,
        String selectedChoiceTitle,
        String outcomeTitle,
        String outcomeSummary,
        MaterialRewardSnapshot materialReward
) {
    public ExpeditionEventSnapshot {
        choices = choices == null ? List.of() : List.copyOf(choices);
    }

    public ExpeditionEventSnapshot(
            String eventId,
            String title,
            String summary,
            String status,
            List<ExpeditionEventChoiceSnapshot> choices,
            String selectedChoiceId,
            String selectedChoiceTitle,
            String outcomeTitle,
            String outcomeSummary
    ) {
        this(
                eventId,
                title,
                summary,
                status,
                choices,
                selectedChoiceId,
                selectedChoiceTitle,
                outcomeTitle,
                outcomeSummary,
                null
        );
    }
}
