package com.walkingrpg.backend.home.domain;

import java.util.List;

public record ExpeditionEventSnapshot(
        String eventId,
        String title,
        String summary,
        String status,
        List<ExpeditionEventChoiceSnapshot> choices,
        List<ExpeditionEventChoiceSnapshot> lockedChoices,
        String selectedChoiceId,
        String selectedChoiceTitle,
        String outcomeTitle,
        String outcomeSummary,
        MaterialRewardSnapshot materialReward
) {
    public ExpeditionEventSnapshot {
        choices = choices == null ? List.of() : List.copyOf(choices);
        lockedChoices = lockedChoices == null
                ? List.of()
                : List.copyOf(lockedChoices);
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
            String outcomeSummary,
            MaterialRewardSnapshot materialReward
    ) {
        this(
                eventId,
                title,
                summary,
                status,
                choices,
                List.of(),
                selectedChoiceId,
                selectedChoiceTitle,
                outcomeTitle,
                outcomeSummary,
                materialReward
        );
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
                List.of(),
                selectedChoiceId,
                selectedChoiceTitle,
                outcomeTitle,
                outcomeSummary,
                null
        );
    }
}
