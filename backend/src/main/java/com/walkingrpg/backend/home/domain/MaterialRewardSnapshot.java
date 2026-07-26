package com.walkingrpg.backend.home.domain;

public record MaterialRewardSnapshot(
        String itemId,
        String itemName,
        String description,
        long quantityGained,
        long quantityAfter,
        long version
) {
}
