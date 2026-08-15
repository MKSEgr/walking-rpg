package com.walkingrpg.backend.itemupgrade.domain;

import java.time.Instant;
import java.util.UUID;

import com.walkingrpg.backend.inventory.domain.UniqueItemRarity;

public record UpgradedUniqueItemResult(
        UUID itemInstanceId,
        String itemId,
        String name,
        String description,
        long previousLevel,
        long upgradeLevel,
        UniqueItemRarity rarity,
        Instant upgradedAt
) {
    public UpgradedUniqueItemResult {
        if (itemInstanceId == null || itemId == null || itemId.isBlank()
                || name == null || name.isBlank()
                || description == null || description.isBlank()
                || previousLevel <= 0 || upgradeLevel != previousLevel + 1
                || rarity == null || upgradedAt == null) {
            throw new IllegalArgumentException("Upgraded unique item неполный");
        }
    }
}
