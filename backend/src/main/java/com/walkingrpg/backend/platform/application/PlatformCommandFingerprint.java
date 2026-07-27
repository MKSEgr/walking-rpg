package com.walkingrpg.backend.platform.application;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.Map;
import java.util.TreeMap;

import tools.jackson.core.JacksonException;
import tools.jackson.databind.ObjectMapper;

public final class PlatformCommandFingerprint {

    private PlatformCommandFingerprint() {
    }

    public static String sha256(
            ObjectMapper objectMapper,
            String commandType,
            Map<String, Object> payload
    ) {
        try {
            Map<String, Object> canonical = new TreeMap<>();
            canonical.put("commandType", commandType);
            canonical.put("payload", payload == null ? Map.of() : payload);
            byte[] bytes = objectMapper.writeValueAsString(canonical)
                    .getBytes(StandardCharsets.UTF_8);
            return HexFormat.of().formatHex(
                    MessageDigest.getInstance("SHA-256").digest(bytes)
            );
        } catch (JacksonException | NoSuchAlgorithmException exception) {
            throw new IllegalStateException("Не удалось рассчитать platform fingerprint", exception);
        }
    }
}
