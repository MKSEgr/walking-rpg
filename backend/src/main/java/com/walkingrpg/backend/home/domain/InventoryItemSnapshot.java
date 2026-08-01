package com.walkingrpg.backend.home.domain;

import java.util.UUID;

public record InventoryItemSnapshot(
        String itemId,
        String name,
        String description,
        long quantity,
        long version,
        String kind,
        UUID itemInstanceId,
        String equippableSlotId,
        String equippedSlotId
) {
    public InventoryItemSnapshot(
            String itemId,
            String name,
            String description,
            long quantity,
            long version,
            String kind
    ) {
        this(
                itemId,
                name,
                description,
                quantity,
                version,
                kind,
                null,
                null,
                null
        );
    }

    public InventoryItemSnapshot(
            String itemId,
            String name,
            String description,
            long quantity,
            long version
    ) {
        this(
                itemId,
                name,
                description,
                quantity,
                version,
                "MATERIAL",
                null,
                null,
                null
        );
    }
}
