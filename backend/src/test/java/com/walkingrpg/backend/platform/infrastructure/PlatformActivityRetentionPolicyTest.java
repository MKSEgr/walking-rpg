package com.walkingrpg.backend.platform.infrastructure;

import java.math.BigDecimal;
import java.util.Map;
import java.util.stream.Stream;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.MethodSource;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class PlatformActivityRetentionPolicyTest {

    @Test
    void shouldUsePublishedActivityRetentionDays() {
        PlatformActivityRetentionPolicy policy = policyWith(
                Map.of("activityRetentionDays", new BigDecimal("90.0"))
        );

        assertEquals(90, policy.retentionDays());
    }

    @Test
    void shouldReadTheCurrentlyActiveConfigForEveryCleanup() {
        PlatformRepository repository = mock(PlatformRepository.class);
        when(repository.activeRemoteConfig()).thenReturn(
                Map.of("activityRetentionDays", 30),
                Map.of("activityRetentionDays", 90)
        );
        PlatformActivityRetentionPolicy policy =
                new PlatformActivityRetentionPolicy(repository);

        assertEquals(30, policy.retentionDays());
        assertEquals(90, policy.retentionDays());
        verify(repository, times(2)).activeRemoteConfig();
    }

    @ParameterizedTest
    @MethodSource("missingOrInvalidConfigs")
    void shouldUseClientDefaultWhenPublishedValueIsMissingOrInvalid(
            Map<String, Object> config
    ) {
        PlatformActivityRetentionPolicy policy = policyWith(config);

        assertEquals(30, policy.retentionDays());
    }

    private static Stream<Map<String, Object>> missingOrInvalidConfigs() {
        return Stream.of(
                Map.of(),
                Map.of("activityRetentionDays", "90"),
                Map.of("activityRetentionDays", BigDecimal.valueOf(30.5)),
                Map.of("activityRetentionDays", 0),
                Map.of("activityRetentionDays", 3651),
                Map.of("activityRetentionDays", Long.MAX_VALUE),
                Map.of("activityRetentionDays", Double.NaN)
        );
    }

    private static PlatformActivityRetentionPolicy policyWith(
            Map<String, Object> config
    ) {
        PlatformRepository repository = mock(PlatformRepository.class);
        when(repository.activeRemoteConfig()).thenReturn(config);
        return new PlatformActivityRetentionPolicy(repository);
    }
}
