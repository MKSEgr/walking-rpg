package com.walkingrpg.backend.platform.application;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;

import tools.jackson.databind.SerializationFeature;
import tools.jackson.databind.json.JsonMapper;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class PlatformCommandFingerprintTest {

    @Test
    void shouldCanonicalizeObjectKeysRecursively() {
        Map<String, Object> firstNested = orderedMap(
                "status", "READY",
                "recipeId", "resonance-compass-v1"
        );
        Map<String, Object> secondNested = orderedMap(
                "recipeId", "resonance-compass-v1",
                "status", "READY"
        );
        Map<String, Object> first = orderedMap(
                "impression", "RECIPE_READY",
                "contentVersion", "chapter-1-v2",
                "context", firstNested
        );
        Map<String, Object> reordered = orderedMap(
                "context", secondNested,
                "contentVersion", "chapter-1-v2",
                "impression", "RECIPE_READY"
        );

        assertEquals(
                PlatformCommandFingerprint.sha256(
                        "RECORD_COMPASS_IMPRESSION",
                        first
                ),
                PlatformCommandFingerprint.sha256(
                        "RECORD_COMPASS_IMPRESSION",
                        reordered
                )
        );
        assertNotEquals(
                PlatformCommandFingerprint.legacySha256(
                        "RECORD_COMPASS_IMPRESSION",
                        first
                ),
                PlatformCommandFingerprint.legacySha256(
                        "RECORD_COMPASS_IMPRESSION",
                        reordered
                )
        );
    }

    @Test
    void shouldKeepArrayOrderAndScalarValuesSignificant() {
        String first = PlatformCommandFingerprint.sha256(
                "TEST",
                Map.of("values", List.of("a", "b"), "enabled", true)
        );
        String reorderedArray = PlatformCommandFingerprint.sha256(
                "TEST",
                Map.of("enabled", true, "values", List.of("b", "a"))
        );
        String changedScalar = PlatformCommandFingerprint.sha256(
                "TEST",
                Map.of("values", List.of("a", "b"), "enabled", false)
        );

        assertNotEquals(first, reorderedArray);
        assertNotEquals(first, changedScalar);
    }

    @Test
    void shouldBoundHistoricalOrdersAndFormattingCandidates() {
        Map<String, Object> first = orderedMap(
                "impression", "ROUTE_AVAILABLE",
                "contentVersion", "chapter-1-v2"
        );
        Map<String, Object> reversed = orderedMap(
                "contentVersion", "chapter-1-v2",
                "impression", "ROUTE_AVAILABLE"
        );

        Set<String> candidates = PlatformCommandFingerprint.legacySha256Candidates(
                JsonMapper.builder().build(),
                "RECORD_COMPASS_IMPRESSION",
                first
        );

        assertTrue(candidates.size() <= 9);
        assertTrue(candidates.contains(PlatformCommandFingerprint.legacySha256(
                "RECORD_COMPASS_IMPRESSION",
                first
        )));
        assertTrue(candidates.contains(PlatformCommandFingerprint.legacySha256(
                "RECORD_COMPASS_IMPRESSION",
                reversed
        )));
    }

    @Test
    void shouldRecognizePreStabilizationIndentedApiMapperEncoding()
            throws Exception {
        String commandType = "COMPLETE_ONBOARDING_STEP";
        Map<String, Object> payload = Map.of("stepId", "welcome");
        JsonMapper historicalMapper = JsonMapper.builder()
                .enable(SerializationFeature.INDENT_OUTPUT)
                .build();
        String historicalFingerprint = previousApiMapperFingerprint(
                historicalMapper,
                commandType,
                payload
        );

        Set<String> candidates = PlatformCommandFingerprint.legacySha256Candidates(
                JsonMapper.builder().build(),
                commandType,
                payload
        );

        assertTrue(candidates.contains(historicalFingerprint));
    }

    @Test
    void shouldPreserveExistingDefaultCanonicalEncoding() {
        assertEquals(
                "4c4e9e7ff71a6e8e6bf5fd7421f73673808a33f98e1c651c4cca1e327a49aaf2",
                PlatformCommandFingerprint.sha256(
                        "RECORD_COMPASS_IMPRESSION",
                        Map.of(
                                "impression", "RECIPE_READY",
                                "contentVersion", "chapter-1-v2"
                        )
                )
        );
    }

    private Map<String, Object> orderedMap(
            String firstKey,
            Object firstValue,
            String secondKey,
            Object secondValue
    ) {
        Map<String, Object> result = new LinkedHashMap<>();
        result.put(firstKey, firstValue);
        result.put(secondKey, secondValue);
        return result;
    }

    private Map<String, Object> orderedMap(
            String firstKey,
            Object firstValue,
            String secondKey,
            Object secondValue,
            String thirdKey,
            Object thirdValue
    ) {
        Map<String, Object> result = orderedMap(
                firstKey,
                firstValue,
                secondKey,
                secondValue
        );
        result.put(thirdKey, thirdValue);
        return result;
    }

    private String previousApiMapperFingerprint(
            JsonMapper mapper,
            String commandType,
            Map<String, Object> payload
    ) throws Exception {
        Map<String, Object> envelope = new TreeMap<>();
        envelope.put("commandType", commandType);
        envelope.put("payload", new TreeMap<>(payload));
        byte[] bytes = mapper.writeValueAsString(envelope)
                .getBytes(StandardCharsets.UTF_8);
        return HexFormat.of().formatHex(
                MessageDigest.getInstance("SHA-256").digest(bytes)
        );
    }
}
