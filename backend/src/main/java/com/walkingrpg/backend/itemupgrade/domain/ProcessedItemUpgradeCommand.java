package com.walkingrpg.backend.itemupgrade.domain;

public record ProcessedItemUpgradeCommand(
        String requestFingerprint,
        ItemUpgradeResult result
) {
}
