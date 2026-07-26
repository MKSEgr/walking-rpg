package com.walkingrpg.backend.expedition.domain;

public record EventMaterialRewardResult(
        String itemId,
        String name,
        String description,
        long quantityGained,
        long quantityAfter,
        long version
) {
    public EventMaterialRewardResult {
        if (itemId == null || itemId.isBlank()) {
            throw new IllegalArgumentException("itemId обязателен");
        }
        if (name == null || name.isBlank()) {
            throw new IllegalArgumentException("name обязателен");
        }
        if (description == null || description.isBlank()) {
            throw new IllegalArgumentException("description обязателен");
        }
        itemId = itemId.trim();
        name = name.trim();
        description = description.trim();
        if (quantityGained <= 0 || quantityAfter < quantityGained || version <= 0) {
            throw new IllegalArgumentException("Некорректный material reward");
        }
    }
}
