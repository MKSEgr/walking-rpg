package com.walkingrpg.backend.expedition.application;

public class EventChoiceSkillUnavailableException extends RuntimeException {

    private final String choiceId;
    private final String requiredSkillId;

    public EventChoiceSkillUnavailableException(
            String choiceId,
            String requiredSkillId
    ) {
        super("Выбор недоступен без требуемого навыка пилота");
        this.choiceId = choiceId;
        this.requiredSkillId = requiredSkillId;
    }

    public String choiceId() {
        return choiceId;
    }

    public String requiredSkillId() {
        return requiredSkillId;
    }
}
