package com.walkingrpg.backend.home.domain;

public record InventoryItemSnapshot(
        String itemId,
        String name,
        String description,
        long quantity,
        long version,
        String kind
) {
    public InventoryItemSnapshot(
            String itemId,
            String name,
            String description,
            long quantity,
            long version
    ) {
        this(itemId, name, description, quantity, version, "MATERIAL");
    }
}
