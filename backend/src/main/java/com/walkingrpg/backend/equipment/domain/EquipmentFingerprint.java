package com.walkingrpg.backend.equipment.domain;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;

public final class EquipmentFingerprint {

    private EquipmentFingerprint() {
    }

    public static String sha256(EquipmentCommand command) {
        String item = command.itemInstanceId() == null
                ? ""
                : command.itemInstanceId().toString();
        String canonical = lengthPrefixed(command.slotId())
                + lengthPrefixed(command.action().name())
                + lengthPrefixed(item);
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
