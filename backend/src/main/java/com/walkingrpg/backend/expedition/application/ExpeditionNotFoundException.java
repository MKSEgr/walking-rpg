package com.walkingrpg.backend.expedition.application;

public class ExpeditionNotFoundException extends RuntimeException {

    private final String expeditionId;

    public ExpeditionNotFoundException(String expeditionId) {
        super("Экспедиция не найдена");
        this.expeditionId = expeditionId;
    }

    public String expeditionId() {
        return expeditionId;
    }
}
