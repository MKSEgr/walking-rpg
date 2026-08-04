package com.walkingrpg.backend.platform.application;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

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
    void shouldRecognizeBothHistoricalOrdersForDeclaredTwoFieldPayloads() {
        Map<String, Object> first = orderedMap(
                "impression", "ROUTE_AVAILABLE",
                "contentVersion", "chapter-1-v2"
        );
        Map<String, Object> reversed = orderedMap(
                "contentVersion", "chapter-1-v2",
                "impression", "ROUTE_AVAILABLE"
        );

        Set<String> candidates = PlatformCommandFingerprint.legacySha256Candidates(
                "RECORD_COMPASS_IMPRESSION",
                first
        );

        assertEquals(2, candidates.size());
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
}
