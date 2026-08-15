package com.walkingrpg.backend.itemupgrade.domain;

public record ItemUpgradeCommand(
        String userId,
        String upgradeId,
        String idempotencyKey
) {
}
