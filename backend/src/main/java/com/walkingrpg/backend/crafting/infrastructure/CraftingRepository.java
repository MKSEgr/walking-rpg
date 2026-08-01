package com.walkingrpg.backend.crafting.infrastructure;

import java.time.Instant;
import java.util.Optional;

import com.walkingrpg.backend.crafting.domain.CraftingIdempotencyScope;
import com.walkingrpg.backend.crafting.domain.CraftingRecipeDefinition;
import com.walkingrpg.backend.crafting.domain.CraftingResult;
import com.walkingrpg.backend.crafting.domain.ProcessedCraftingCommand;

public interface CraftingRepository {

    void acquireLock(String userId);

    Optional<ProcessedCraftingCommand> findProcessed(
            CraftingIdempotencyScope scope
    );

    CraftingResult createUniqueItem(
            CraftingIdempotencyScope scope,
            String requestFingerprint,
            CraftingRecipeDefinition recipe,
            Instant serverTime
    );
}
