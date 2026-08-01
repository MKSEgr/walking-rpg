package com.walkingrpg.backend.home.domain;

import java.util.UUID;

public record EquipmentItemSnapshot(
        UUID itemInstanceId,
        String itemId,
        String name,
        String description
) {
}
