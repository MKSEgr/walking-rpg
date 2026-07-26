package com.walkingrpg.backend.progression.domain;

public record PetProgressState(
        int level,
        int bond,
        long version
) {
    public PetProgressState {
        if (level <= 0) {
            throw new IllegalArgumentException("Уровень питомца должен быть положительным");
        }
        if (bond < 0) {
            throw new IllegalArgumentException("Связь питомца не может быть отрицательной");
        }
        if (version < 0) {
            throw new IllegalArgumentException("Версия питомца не может быть отрицательной");
        }
    }

    public static PetProgressState initial(PetDefinition definition) {
        return new PetProgressState(
                definition.initialLevel(),
                definition.initialBond(),
                0
        );
    }

    public PetProgressState reward(int bondGained) {
        if (bondGained < 0) {
            throw new IllegalArgumentException("bondGained не может быть отрицательной");
        }
        if (bondGained == 0) {
            return this;
        }
        return new PetProgressState(level, bond + bondGained, version + 1);
    }
}
