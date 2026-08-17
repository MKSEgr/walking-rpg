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
        if (status == ExpeditionProgressStatus.IN_PROGRESS && unlockedEventId != null) {
            throw new IllegalArgumentException("IN_PROGRESS не должен содержать unlockedEventId");
        }
        if (status != ExpeditionProgressStatus.IN_PROGRESS && unlockedEventId == null) {
            throw new IllegalArgumentException(status + " требует unlockedEventId");
        }
        if (status != ExpeditionProgressStatus.IN_PROGRESS
                && progressEnergy != requiredEnergy) {
            throw new IllegalArgumentException(status + " требует достигнутый узел");
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
        if (status != ExpeditionProgressStatus.IN_PROGRESS) {
            throw new IllegalStateException("Продвижение возможно только из IN_PROGRESS");
        }
        if (!currentNodeId.equals(definition.currentNodeId())
                || requiredEnergy != definition.requiredEnergy()) {
            throw new IllegalStateException("Состояние узла не совпадает с content definition");
        }
        if (energy <= 0 || energy > remainingEnergy()) {
            throw new IllegalArgumentException("Некорректное количество энергии для продвижения");
        }
        long nextProgress = Math.addExact(progressEnergy, energy);
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

    public ExpeditionProgressState resolveAndContinue(
            String eventId,
            ExpeditionDefinition nextNode
    ) {
        validateResolution(eventId);
        return new ExpeditionProgressState(
                0,
                nextNode.requiredEnergy(),
                ExpeditionProgressStatus.IN_PROGRESS,
                nextNode.currentNodeId(),
                null,
                version + 1
        );
    }

    public ExpeditionProgressState resolveAndComplete(String eventId) {
        validateResolution(eventId);
        return new ExpeditionProgressState(
                progressEnergy,
                requiredEnergy,
                ExpeditionProgressStatus.COMPLETED,
                currentNodeId,
                unlockedEventId,
                version + 1
        );
    }

    public ExpeditionProgressState beginNextJourney(
            ExpeditionDefinition initialDefinition
    ) {
        Objects.requireNonNull(initialDefinition, "initialDefinition");
        if (status != ExpeditionProgressStatus.COMPLETED) {
            throw new IllegalStateException(
                    "Новый поход доступен только после завершения экспедиции"
            );
        }
        return new ExpeditionProgressState(
                0,
                initialDefinition.requiredEnergy(),
                ExpeditionProgressStatus.IN_PROGRESS,
                initialDefinition.currentNodeId(),
                null,
                version + 1
        );
    }

    /** Backward-compatible helper for the final node semantics. */
    public ExpeditionProgressState resolve(String eventId) {
        return resolveAndComplete(eventId);
    }

    private void validateResolution(String eventId) {
        if (status != ExpeditionProgressStatus.EVENT_READY) {
            throw new IllegalStateException("Разрешение возможно только из EVENT_READY");
        }
        if (!Objects.equals(unlockedEventId, eventId)) {
            throw new IllegalArgumentException("Разрешается неоткрытое событие");
        }
    }
}
