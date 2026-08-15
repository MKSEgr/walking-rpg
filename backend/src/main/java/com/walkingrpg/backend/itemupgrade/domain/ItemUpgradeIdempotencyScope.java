package com.walkingrpg.backend.itemupgrade.domain;

public record ItemUpgradeIdempotencyScope(
        String userId,
        String upgradeId,
        String idempotencyKey
) {
    public static ItemUpgradeIdempotencyScope from(ItemUpgradeCommand command) {
        return new ItemUpgradeIdempotencyScope(
                command.userId(),
                command.upgradeId(),
                command.idempotencyKey()
        );
    }
}
