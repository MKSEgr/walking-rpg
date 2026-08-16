package com.walkingrpg.backend.expedition.application;

public class EventChoicePetUnavailableException extends RuntimeException {

    private final String choiceId;
    private final String requiredPetId;
    private final int requiredEvolutionStage;
    private final int actualEvolutionStage;

    public EventChoicePetUnavailableException(
            String choiceId,
            String requiredPetId
    ) {
        this(choiceId, requiredPetId, 0, 0);
    }

    public EventChoicePetUnavailableException(
            String choiceId,
            String requiredPetId,
            int requiredEvolutionStage,
            int actualEvolutionStage
    ) {
        super(requiredEvolutionStage > actualEvolutionStage
                ? "Выбор недоступен до требуемой эволюции активного питомца"
                : "Выбор недоступен без требуемого активного питомца");
        this.choiceId = choiceId;
        this.requiredPetId = requiredPetId;
        this.requiredEvolutionStage = requiredEvolutionStage;
        this.actualEvolutionStage = actualEvolutionStage;
    }

    public String choiceId() {
        return choiceId;
    }

    public String requiredPetId() {
        return requiredPetId;
    }

    public int requiredEvolutionStage() {
        return requiredEvolutionStage;
    }

    public int actualEvolutionStage() {
        return actualEvolutionStage;
    }
}
