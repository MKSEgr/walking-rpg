package com.walkingrpg.backend.expedition.application;

public class EventChoiceUnavailableException extends RuntimeException {

    private final String choiceId;
    private final String slotId;
    private final String requiredItemId;

    public EventChoiceUnavailableException(
            String choiceId,
            String slotId,
            String requiredItemId
    ) {
        super("Выбор недоступен без требуемого экипированного предмета");
        this.choiceId = choiceId;
        this.slotId = slotId;
        this.requiredItemId = requiredItemId;
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
}
