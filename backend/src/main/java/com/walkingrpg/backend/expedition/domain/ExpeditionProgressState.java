package com.walkingrpg.backend.expedition.domain;

import java.util.Objects;

public record ExpeditionProgressState(
        long progressEnergy,
        long requiredEnergy,
        ExpeditionProgressStatus status,
        String currentNodeId,
        String unlockedEventId,
        long version
) {
    public ExpeditionProgressState {
        if (progressEnergy < 0 || requiredEnergy <= 0 || progressEnergy > requiredEnergy) {
            throw new IllegalArgumentException("Некорректный progress экспедиции");
        }
        Objects.requireNonNull(status, "status");
        Objects.requireNonNull(currentNodeId, "currentNodeId");
        if (version < 0) {
            throw new IllegalArgumentException("Версия экспедиции не может быть отрицательной");
        }
        if (status == ExpeditionProgressStatus.EVENT_READY && unlockedEventId == null) {
            throw new IllegalArgumentException("EVENT_READY требует unlockedEventId");
        }
        if (status == ExpeditionProgressStatus.IN_PROGRESS && unlockedEventId != null) {
            throw new IllegalArgumentException("IN_PROGRESS не должен содержать unlockedEventId");
        }
    }

    public static ExpeditionProgressState initial(ExpeditionDefinition definition) {
        return new ExpeditionProgressState(
                0,
                definition.requiredEnergy(),
                ExpeditionProgressStatus.IN_PROGRESS,
                definition.currentNodeId(),
                null,
                0
        );
    }

    public long remainingEnergy() {
        return requiredEnergy - progressEnergy;
    }

    public ExpeditionProgressState advance(
            long energy,
            ExpeditionDefinition definition
    ) {
        if (energy <= 0 || energy > remainingEnergy()) {
            throw new IllegalArgumentException("Некорректное количество энергии для продвижения");
        }
        long nextProgress = progressEnergy + energy;
        boolean reachedNode = nextProgress == requiredEnergy;
        return new ExpeditionProgressState(
                nextProgress,
                requiredEnergy,
                reachedNode
                        ? ExpeditionProgressStatus.EVENT_READY
                        : ExpeditionProgressStatus.IN_PROGRESS,
                currentNodeId,
                reachedNode ? definition.event().eventId() : null,
                version + 1
        );
    }
}
