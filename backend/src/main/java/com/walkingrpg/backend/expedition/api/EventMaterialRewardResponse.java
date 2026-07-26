package com.walkingrpg.backend.expedition.api;

public record EventMaterialRewardResponse(
        String itemId,
        String name,
        String description,
        long quantityGained,
        long quantityAfter,
        long version
) {
}
