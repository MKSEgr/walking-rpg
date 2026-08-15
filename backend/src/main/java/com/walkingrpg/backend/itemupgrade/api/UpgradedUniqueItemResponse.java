package com.walkingrpg.backend.itemupgrade.api;

import java.time.Instant;
import java.util.UUID;

public record UpgradedUniqueItemResponse(
        UUID itemInstanceId,
        String itemId,
        String name,
        String description,
        long previousLevel,
        long upgradeLevel,
        String rarity,
        Instant upgradedAt
) {
}
