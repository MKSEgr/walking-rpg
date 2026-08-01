package com.walkingrpg.backend.crafting.domain;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;

public final class CraftingFingerprint {

    private CraftingFingerprint() {
    }

    public static String sha256(CraftingCommand command) {
        String canonical = command.recipeId().length()
                + ":"
                + command.recipeId()
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
