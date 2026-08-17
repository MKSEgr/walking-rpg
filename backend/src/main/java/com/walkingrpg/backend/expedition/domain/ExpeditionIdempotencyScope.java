package com.walkingrpg.backend.expedition.domain;

public record ExpeditionIdempotencyScope(
        String userId,
        String expeditionId,
        String idempotencyKey
) {
    public static ExpeditionIdempotencyScope from(ExpeditionAdvanceCommand command) {
        return new ExpeditionIdempotencyScope(
                command.userId(),
                command.expeditionId(),
                command.idempotencyKey()
        );
    }

    public static ExpeditionIdempotencyScope from(
            ExpeditionJourneyCommand command
    ) {
        return new ExpeditionIdempotencyScope(
                command.userId(),
                command.expeditionId(),
                command.idempotencyKey()
        );
    }
}
