package com.walkingrpg.backend.itemupgrade.domain;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;

public final class ItemUpgradeFingerprint {

    private ItemUpgradeFingerprint() {
    }

    public static String sha256(ItemUpgradeCommand command) {
        String canonical = command.upgradeId().length()
                + ":"
                + command.upgradeId()
                + ";";
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
