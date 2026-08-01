package com.walkingrpg.backend.equipment.application;

import java.util.List;
import java.util.Optional;

import com.walkingrpg.backend.equipment.domain.EquipmentSlotDefinition;
import com.walkingrpg.backend.inventory.application.StarterInventoryContent;
import com.walkingrpg.backend.inventory.domain.InventoryItemDefinition;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

@Component
public class StarterEquipmentContent {

    public static final String CONTENT_VERSION = "equipment-v1";
    public static final String NAVIGATION_SLOT_ID = "NAVIGATION";

    private final EquipmentSlotDefinition navigationSlot =
            new EquipmentSlotDefinition(
                    NAVIGATION_SLOT_ID,
                    "Навигационный прибор",
                    "Один уникальный инструмент, влияющий на доступные маршруты."
            );
    private final StarterInventoryContent inventoryContent;

    public StarterEquipmentContent() {
        this(new StarterInventoryContent());
    }

    @Autowired
    public StarterEquipmentContent(StarterInventoryContent inventoryContent) {
        this.inventoryContent = inventoryContent;
    }

    public EquipmentSlotDefinition requireSlot(String slotId) {
        if (!NAVIGATION_SLOT_ID.equals(slotId)) {
            throw new EquipmentSlotNotFoundException(slotId);
        }
        return navigationSlot;
    }

    public InventoryItemDefinition requireEquippable(
            String slotId,
            String itemId
    ) {
        requireSlot(slotId);
        if (!StarterInventoryContent.RESONANCE_COMPASS_ID.equals(itemId)) {
            throw new EquipmentItemUnavailableException(itemId);
        }
        return inventoryContent.require(itemId);
    }

    public List<EquipmentSlotDefinition> slots() {
        return List.of(navigationSlot);
    }

    public Optional<EquipmentSlotDefinition> slotForItem(String itemId) {
        return StarterInventoryContent.RESONANCE_COMPASS_ID.equals(itemId)
                ? Optional.of(navigationSlot)
                : Optional.empty();
    }
}
