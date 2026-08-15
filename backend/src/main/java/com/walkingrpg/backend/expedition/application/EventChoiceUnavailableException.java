package com.walkingrpg.backend.expedition.application;

public class EventChoiceUnavailableException extends RuntimeException {

    private final String choiceId;
    private final String slotId;
    private final String requiredItemId;
    private final long requiredUpgradeLevel;

    public EventChoiceUnavailableException(
            String choiceId,
            String slotId,
            String requiredItemId,
            long requiredUpgradeLevel
    ) {
        super("Выбор недоступен без требуемого экипированного предмета");
        this.choiceId = choiceId;
        this.slotId = slotId;
        this.requiredItemId = requiredItemId;
        this.requiredUpgradeLevel = requiredUpgradeLevel;
    }

    public EventChoiceUnavailableException(
            String choiceId,
            String slotId,
            String requiredItemId
    ) {
        this(choiceId, slotId, requiredItemId, 1);
    }

    public String choiceId() {
        return choiceId;
    }

    public String slotId() {
        return slotId;
    }

    public String requiredItemId() {
        return requiredItemId;
    }

    public long requiredUpgradeLevel() {
        return requiredUpgradeLevel;
    }
}
