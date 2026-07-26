package com.walkingrpg.backend.expedition.application;

public class EventNotFoundException extends RuntimeException {

    private final String eventId;

    public EventNotFoundException(String eventId) {
        super("Событие не найдено: " + eventId);
        this.eventId = eventId;
    }

    public String eventId() {
        return eventId;
    }
}
