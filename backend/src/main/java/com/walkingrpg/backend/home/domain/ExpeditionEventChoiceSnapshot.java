package com.walkingrpg.backend.home.domain;

public record ExpeditionEventChoiceSnapshot(
        String choiceId,
        String title,
        String description,
        int pilotExperienceReward,
        int petBondReward
) {
}
