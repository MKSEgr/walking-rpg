package com.walkingrpg.backend.progression.domain;

public record PilotProgressState(
        int level,
        int currentExperience,
        int nextLevelExperience,
        long version
) {
    private static final int LEVEL_THRESHOLD_STEP = 50;

    public PilotProgressState {
        if (level <= 0) {
            throw new IllegalArgumentException("Уровень пилота должен быть положительным");
        }
        if (currentExperience < 0 || nextLevelExperience <= 0
                || currentExperience >= nextLevelExperience) {
            throw new IllegalArgumentException("Некорректное состояние опыта пилота");
        }
        if (version < 0) {
            throw new IllegalArgumentException("Версия пилота не может быть отрицательной");
        }
    }

    public static PilotProgressState initial(PilotDefinition definition) {
        return new PilotProgressState(
                definition.initialLevel(),
                definition.initialExperience(),
                definition.nextLevelExperience(),
                0
        );
    }

    public PilotProgressState reward(int experienceGained) {
        if (experienceGained < 0) {
            throw new IllegalArgumentException("experienceGained не может быть отрицательным");
        }
        if (experienceGained == 0) {
            return this;
        }

        int nextLevel = level;
        int nextExperience = currentExperience + experienceGained;
        int nextThreshold = nextLevelExperience;
        while (nextExperience >= nextThreshold) {
            nextExperience -= nextThreshold;
            nextLevel += 1;
            nextThreshold += LEVEL_THRESHOLD_STEP;
        }
        return new PilotProgressState(
                nextLevel,
                nextExperience,
                nextThreshold,
                version + 1
        );
    }
}
