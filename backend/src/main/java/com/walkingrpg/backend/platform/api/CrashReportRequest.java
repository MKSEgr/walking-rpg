package com.walkingrpg.backend.platform.api;

import java.time.Instant;
import java.util.Map;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CrashReportRequest(
        @NotBlank @Size(max = 32) String platform,
        @NotBlank @Size(max = 64) String appVersion,
        @NotBlank @Size(max = 160) String errorType,
        @NotBlank @Size(max = 2000) String message,
        @Size(max = 32768) String stackTrace,
        @Size(max = 64) Map<String, Object> context,
        Instant occurredAt
) {
    public CrashReportRequest {
        context = context == null ? Map.of() : Map.copyOf(context);
    }
}
