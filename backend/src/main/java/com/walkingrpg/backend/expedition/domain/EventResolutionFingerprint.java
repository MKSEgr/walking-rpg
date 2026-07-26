package com.walkingrpg.backend.expedition.domain;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;

public final class EventResolutionFingerprint {

    private EventResolutionFingerprint() {
    }

    public static String sha256(EventResolutionCommand command) {
        String canonical = lengthPrefixed(command.eventId())
                + lengthPrefixed(command.choiceId());
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(
                    digest.digest(canonical.getBytes(StandardCharsets.UTF_8))
            );
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 недоступен", exception);
        }
    }

    private static String lengthPrefixed(String value) {
        return value.length() + ":" + value + ";";
    }
}
