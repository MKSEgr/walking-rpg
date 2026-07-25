package com.walkingrpg.backend.shared.api;

import java.util.Map;
import java.util.UUID;

public record ApiErrorResponse(
        String code,
        String message,
        Map<String, Object> details,
        UUID traceId
) {
}
