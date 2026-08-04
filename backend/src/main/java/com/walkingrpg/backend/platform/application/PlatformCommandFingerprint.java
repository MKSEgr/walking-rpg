package com.walkingrpg.backend.platform.application;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
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
        return hash(
                objectMapper,
                commandType,
                canonicalize(payload == null ? Map.of() : payload)
        );
    }

    static Set<String> legacySha256Candidates(
            ObjectMapper objectMapper,
            String commandType,
            Map<String, Object> payload
    ) {
        Map<String, Object> value = payload == null ? Map.of() : payload;
        Set<String> candidates = new LinkedHashSet<>();
        candidates.add(legacySha256(objectMapper, commandType, value));

        // Every declared platform command has at most two top-level payload
        // fields. Before canonical fingerprints, Map.copyOf could expose either
        // order in a different JVM. Cover both historical two-field encodings
        // without factorial work on an untrusted oversized map.
        if (value.size() == 2) {
            List<Map.Entry<String, Object>> entries = new ArrayList<>(value.entrySet());
            Map<String, Object> reversed = new LinkedHashMap<>();
            reversed.put(entries.get(1).getKey(), entries.get(1).getValue());
            reversed.put(entries.get(0).getKey(), entries.get(0).getValue());
            candidates.add(legacySha256(objectMapper, commandType, reversed));
        }
        return Set.copyOf(candidates);
    }

    static String legacySha256(
            ObjectMapper objectMapper,
            String commandType,
            Map<String, Object> payload
    ) {
        return hash(objectMapper, commandType, payload == null ? Map.of() : payload);
    }

    private static String hash(
            ObjectMapper objectMapper,
            String commandType,
            Object payload
    ) {
        try {
            Map<String, Object> canonical = new TreeMap<>();
            canonical.put("commandType", commandType);
            canonical.put("payload", payload);
            byte[] bytes = objectMapper.writeValueAsString(canonical)
                    .getBytes(StandardCharsets.UTF_8);
            return HexFormat.of().formatHex(
                    MessageDigest.getInstance("SHA-256").digest(bytes)
            );
        } catch (JacksonException | NoSuchAlgorithmException exception) {
            throw new IllegalStateException("Не удалось рассчитать platform fingerprint", exception);
        }
    }

    private static Object canonicalize(Object value) {
        if (value instanceof Map<?, ?> map) {
            Map<String, Object> sorted = new TreeMap<>();
            for (Map.Entry<?, ?> entry : map.entrySet()) {
                if (!(entry.getKey() instanceof String key)) {
                    throw new IllegalArgumentException(
                            "Platform payload object keys must be strings"
                    );
                }
                sorted.put(key, canonicalize(entry.getValue()));
            }
            return sorted;
        }
        if (value instanceof List<?> list) {
            List<Object> canonical = new ArrayList<>(list.size());
            list.forEach(item -> canonical.add(canonicalize(item)));
            return Collections.unmodifiableList(canonical);
        }
        return value;
    }
}
