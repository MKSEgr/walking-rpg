package com.walkingrpg.backend.expedition.application;

public class EventChoicePetUnavailableException extends RuntimeException {

    private final String choiceId;
    private final String requiredPetId;

    public EventChoicePetUnavailableException(
            String choiceId,
            String requiredPetId
    ) {
        super("Выбор недоступен без требуемого активного питомца");
        this.choiceId = choiceId;
        this.requiredPetId = requiredPetId;
    }

    public String choiceId() {
        return choiceId;
    }

    public String requiredPetId() {
        return requiredPetId;
    }
}
