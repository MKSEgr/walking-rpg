package com.walkingrpg.backend.expedition.domain;

public record EventIdempotencyScope(
        String userId,
        String eventId,
        String idempotencyKey
) {
    public static EventIdempotencyScope from(EventResolutionCommand command) {
        return new EventIdempotencyScope(
                command.userId(),
                command.eventId(),
                command.idempotencyKey()
        );
    }
}
