package com.walkingrpg.backend.home.domain;

public record ExpeditionEventChoiceSnapshot(
        String choiceId,
        String title,
        String description,
        int pilotExperienceReward,
        int petBondReward,
        MaterialRewardPreviewSnapshot materialReward
) {
    public ExpeditionEventChoiceSnapshot(
            String choiceId,
            String title,
            String description,
            int pilotExperienceReward,
            int petBondReward
    ) {
        this(
                choiceId,
                title,
                description,
                pilotExperienceReward,
                petBondReward,
                null
        );
    }
}
