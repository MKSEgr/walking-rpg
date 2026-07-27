package com.walkingrpg.backend.platform.api;

import java.time.Instant;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;

public record PlatformSnapshotResponse(
        String contentVersion,
        long stateVersion,
        Map<String, Object> userState,
        Map<String, Object> content,
        Map<String, Object> remoteConfig,
        Instant serverTime
) {
    public PlatformSnapshotResponse {
        userState = immutableMap(userState);
        content = immutableMap(content);
        remoteConfig = immutableMap(remoteConfig);
    }

    private static Map<String, Object> immutableMap(Map<String, Object> value) {
        return Collections.unmodifiableMap(new LinkedHashMap<>(value == null ? Map.of() : value));
    }
}
