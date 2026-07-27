package com.walkingrpg.backend.platform.domain;

public record ProcessedPlatformCommand(
        String requestFingerprint,
        String responseJson
) {
    public ProcessedPlatformCommand {
        if (requestFingerprint == null || !requestFingerprint.matches("[0-9a-f]{64}")) {
            throw new IllegalArgumentException("Некорректный requestFingerprint");
        }
        if (responseJson == null || responseJson.isBlank()) {
            throw new IllegalArgumentException("responseJson обязателен");
        }
    }
}
