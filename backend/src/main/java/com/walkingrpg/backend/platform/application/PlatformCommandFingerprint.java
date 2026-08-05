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
import tools.jackson.databind.MapperFeature;
import tools.jackson.databind.ObjectMapper;
import tools.jackson.databind.ObjectWriter;
import tools.jackson.databind.SerializationFeature;
import tools.jackson.databind.json.JsonMapper;

public final class PlatformCommandFingerprint {

    /*
     * Fingerprints are a persistent idempotency contract, so they must not
     * inherit formatting or serializer overrides from Spring's API mapper.
     */
    private static final ObjectWriter CANONICAL_WRITER =
            JsonMapper.builder()
                    .enable(MapperFeature.SORT_PROPERTIES_ALPHABETICALLY)
                    .enable(SerializationFeature.ORDER_MAP_ENTRIES_BY_KEYS)
                    .disable(SerializationFeature.INDENT_OUTPUT)
                    .build()
                    .writer();
    private static final ObjectWriter LEGACY_WRITER =
            JsonMapper.builder()
                    .disable(SerializationFeature.INDENT_OUTPUT)
                    .build()
                    .writer();
    private static final ObjectWriter LEGACY_INDENTED_WRITER =
            JsonMapper.builder()
                    .enable(SerializationFeature.INDENT_OUTPUT)
                    .build()
                    .writer();

    private PlatformCommandFingerprint() {
    }

    public static String sha256(
            String commandType,
            Map<String, Object> payload
    ) {
        return hash(
                CANONICAL_WRITER,
                commandType,
                canonicalize(payload == null ? Map.of() : payload)
        );
    }

    static Set<String> legacySha256Candidates(
            ObjectMapper legacyApiMapper,
            String commandType,
            Map<String, Object> payload
    ) {
        Map<String, Object> value = payload == null ? Map.of() : payload;
        Set<String> candidates = new LinkedHashSet<>();
        addLegacyCandidates(candidates, LEGACY_WRITER, commandType, value);

        /*
         * The immediately preceding binary hashed with Spring's API mapper.
         * Keep its active writer and the known indentation variant as replay-only
         * candidates. New rows still store only the fixed canonical hash.
         */
        addLegacyCandidates(
                candidates,
                legacyApiMapper.writer(),
                commandType,
                value
        );
        addLegacyCandidates(
                candidates,
                LEGACY_INDENTED_WRITER,
                commandType,
                value
        );
        return Set.copyOf(candidates);
    }

    static String legacySha256(
            String commandType,
            Map<String, Object> payload
    ) {
        return hash(LEGACY_WRITER, commandType, payload == null ? Map.of() : payload);
    }

    private static void addLegacyCandidates(
            Set<String> candidates,
            ObjectWriter writer,
            String commandType,
            Map<String, Object> payload
    ) {
        candidates.add(hash(writer, commandType, canonicalize(payload)));
        candidates.add(hash(writer, commandType, payload));

        // Every declared platform command has at most two top-level payload
        // fields. Before canonical fingerprints, Map.copyOf could expose either
        // order in a different JVM. Cover both historical two-field encodings
        // without factorial work on an untrusted oversized map.
        if (payload.size() == 2) {
            List<Map.Entry<String, Object>> entries = new ArrayList<>(payload.entrySet());
            Map<String, Object> reversed = new LinkedHashMap<>();
            reversed.put(entries.get(1).getKey(), entries.get(1).getValue());
            reversed.put(entries.get(0).getKey(), entries.get(0).getValue());
            candidates.add(hash(writer, commandType, reversed));
        }
    }

    private static String hash(
            ObjectWriter writer,
            String commandType,
            Object payload
    ) {
        try {
            Map<String, Object> canonical = new TreeMap<>();
            canonical.put("commandType", commandType);
            canonical.put("payload", payload);
            byte[] bytes = writer.writeValueAsString(canonical)
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
