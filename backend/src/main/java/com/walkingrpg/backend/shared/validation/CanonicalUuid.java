package com.walkingrpg.backend.shared.validation;

import java.util.UUID;

public final class CanonicalUuid {

    private CanonicalUuid() {
    }

    public static UUID parse(String value) {
        if (value == null) {
            throw new IllegalArgumentException("UUID is required");
        }
        UUID parsed = UUID.fromString(value);
        if (!parsed.toString().equalsIgnoreCase(value)) {
            throw new IllegalArgumentException("UUID must use the full canonical form");
        }
        return parsed;
    }
}
