package com.walkingrpg.backend.activity.domain;

public record IdempotencyScope(
        String userId,
        String deviceId,
        String idempotencyKey
) {
    public static IdempotencyScope from(ActivitySyncCommand command) {
        return new IdempotencyScope(
                command.userId(),
                command.deviceId(),
                command.idempotencyKey()
        );
    }
}
