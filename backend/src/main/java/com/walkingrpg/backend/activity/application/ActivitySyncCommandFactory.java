package com.walkingrpg.backend.activity.application;

import java.time.DateTimeException;
import java.time.ZoneId;
import java.util.List;
import java.util.Set;

import com.walkingrpg.backend.activity.api.ActivityBucketRequest;
import com.walkingrpg.backend.activity.api.ActivitySyncRequest;
import com.walkingrpg.backend.activity.domain.ActivityBucket;
import com.walkingrpg.backend.activity.domain.ActivitySyncCommand;
import org.springframework.stereotype.Component;

@Component
public class ActivitySyncCommandFactory {

    private static final Set<String> SUPPORTED_TIME_ZONE_IDS = Set.copyOf(
            ZoneId.getAvailableZoneIds()
    );

    public ActivitySyncCommand create(
            String userId,
            String deviceId,
            ActivitySyncRequest request
    ) {
        String normalizedUserId = requireText(userId, "userId");
        String normalizedDeviceId = requireText(deviceId, "deviceId");
        ZoneId zoneId = parseZoneId(request.timeZone());
        List<ActivityBucket> buckets = request.buckets().stream()
                .map(this::toDomainBucket)
                .toList();

        return new ActivitySyncCommand(
                normalizedUserId,
                normalizedDeviceId,
                request.localDate(),
                zoneId,
                request.authoritativeTotal(),
                buckets,
                normalizeOptional(request.syncCursor()),
                request.idempotencyKey().trim(),
                normalizeOptional(request.attestation())
        );
    }

    private ActivityBucket toDomainBucket(ActivityBucketRequest bucket) {
        if (!bucket.from().isBefore(bucket.to())) {
            throw new ActivitySyncValidationException(
                    "buckets",
                    "Начало временного интервала должно быть раньше окончания"
            );
        }
        return new ActivityBucket(bucket.from(), bucket.to(), bucket.steps());
    }

    private ZoneId parseZoneId(String value) {
        String normalized = value.trim();
        if (!SUPPORTED_TIME_ZONE_IDS.contains(normalized)) {
            throw invalidTimeZone();
        }
        try {
            return ZoneId.of(normalized);
        } catch (DateTimeException exception) {
            throw invalidTimeZone();
        }
    }

    private ActivitySyncValidationException invalidTimeZone() {
        return new ActivitySyncValidationException(
                "timeZone",
                "Ожидается известный IANA идентификатор часового пояса"
        );
    }

    private String requireText(String value, String field) {
        if (value == null || value.isBlank()) {
            throw new ActivitySyncValidationException(field, "Значение обязательно");
        }
        String normalized = value.trim();
        if (normalized.length() > 128) {
            throw new ActivitySyncValidationException(field, "Максимальная длина — 128 символов");
        }
        return normalized;
    }

    private String normalizeOptional(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }
}
