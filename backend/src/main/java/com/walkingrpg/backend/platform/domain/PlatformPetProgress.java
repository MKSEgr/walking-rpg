package com.walkingrpg.backend.platform.domain;

public record PlatformPetProgress(
        int level,
        int bond,
        int evolutionStage
) {
    public PlatformPetProgress {
        if (level <= 0) {
            throw new IllegalArgumentException("Уровень питомца должен быть положительным");
        }
        if (bond < 0 || evolutionStage < 0) {
            throw new IllegalArgumentException("Прогресс питомца не может быть отрицательным");
        }
    }

    public PlatformPetProgress rewardBond(int amount) {
        if (amount < 0) {
            throw new IllegalArgumentException("Награда bond не может быть отрицательной");
        }
        return new PlatformPetProgress(level, Math.addExact(bond, amount), evolutionStage);
    }

    public PlatformPetProgress evolve() {
        return new PlatformPetProgress(level + 1, bond, evolutionStage + 1);
    }
}
