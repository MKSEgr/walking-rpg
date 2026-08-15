package com.walkingrpg.backend.itemupgrade.infrastructure;

import java.time.Instant;
import java.util.Optional;

import com.walkingrpg.backend.itemupgrade.domain.ItemUpgradeDefinition;
import com.walkingrpg.backend.itemupgrade.domain.ItemUpgradeIdempotencyScope;
import com.walkingrpg.backend.itemupgrade.domain.ItemUpgradeResult;
import com.walkingrpg.backend.itemupgrade.domain.ProcessedItemUpgradeCommand;

public interface ItemUpgradeRepository {

    void acquireLock(String userId);

    Optional<ProcessedItemUpgradeCommand> findProcessed(
            ItemUpgradeIdempotencyScope scope
    );

    ItemUpgradeResult upgrade(
            ItemUpgradeIdempotencyScope scope,
            String requestFingerprint,
            ItemUpgradeDefinition definition,
            Instant serverTime
    );
}
