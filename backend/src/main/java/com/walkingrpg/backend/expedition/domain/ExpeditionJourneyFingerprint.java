package com.walkingrpg.backend.expedition.domain;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;

public final class ExpeditionJourneyFingerprint {

    private ExpeditionJourneyFingerprint() {
    }

    public static String sha256(ExpeditionJourneyCommand command) {
        String canonical = command.expeditionId()
                + "\n"
                + command.expectedJourneyNumber();
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(
                    digest.digest(canonical.getBytes(StandardCharsets.UTF_8))
            );
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 недоступен", exception);
        }
    }
}
