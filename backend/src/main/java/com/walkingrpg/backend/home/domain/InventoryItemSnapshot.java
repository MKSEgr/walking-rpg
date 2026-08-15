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
        String equippedSlotId,
        String rarity
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
                null,
                null
        );
    }

    public InventoryItemSnapshot(
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
        this(
                itemId,
                name,
                description,
                quantity,
                version,
                kind,
                itemInstanceId,
                equippableSlotId,
                equippedSlotId,
                null
        );
    }
}
