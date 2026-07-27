package com.walkingrpg.backend.platform.application;

import java.util.Map;

public class PlatformStateConflictException extends RuntimeException {

    private final Map<String, Object> details;

    public PlatformStateConflictException(String message) {
        this(message, Map.of());
    }

    public PlatformStateConflictException(String message, Map<String, Object> details) {
        super(message);
        this.details = details == null ? Map.of() : Map.copyOf(details);
    }

    public Map<String, Object> details() {
        return details;
    }
}
