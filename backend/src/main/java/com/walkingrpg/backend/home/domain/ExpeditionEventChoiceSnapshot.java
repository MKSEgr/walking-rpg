package com.walkingrpg.backend.home.domain;

public record ExpeditionEventChoiceSnapshot(
        String choiceId,
        String title,
        String description,
        int pilotExperienceReward,
        int petBondReward,
        MaterialRewardPreviewSnapshot materialReward,
        String availability,
        ExpeditionChoiceRequirementSnapshot requirement
) {
    public ExpeditionEventChoiceSnapshot(
            String choiceId,
            String title,
            String description,
            int pilotExperienceReward,
            int petBondReward,
            MaterialRewardPreviewSnapshot materialReward
    ) {
        this(
                choiceId,
                title,
                description,
                pilotExperienceReward,
                petBondReward,
                materialReward,
                "AVAILABLE",
                null
        );
    }

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
                null,
                "AVAILABLE",
                null
        );
    }
}
