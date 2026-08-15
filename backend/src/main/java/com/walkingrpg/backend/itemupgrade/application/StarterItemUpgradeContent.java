package com.walkingrpg.backend.itemupgrade.application;

import java.util.List;

import com.walkingrpg.backend.crafting.domain.CraftingIngredientDefinition;
import com.walkingrpg.backend.expedition.application.StarterExpeditionContent;
import com.walkingrpg.backend.inventory.application.StarterInventoryContent;
import com.walkingrpg.backend.inventory.domain.UniqueItemRarity;
import com.walkingrpg.backend.itemupgrade.domain.ItemUpgradeDefinition;
import org.springframework.stereotype.Component;

@Component
public class StarterItemUpgradeContent {

    public static final String CONTENT_VERSION = "item-upgrade-v1";
    public static final String PRISM_SEXTANT_CALIBRATION_ID =
            "prism-sextant-calibration-v1";

    private final ItemUpgradeDefinition prismSextantCalibration;

    public StarterItemUpgradeContent(StarterInventoryContent inventoryContent) {
        prismSextantCalibration = new ItemUpgradeDefinition(
                CONTENT_VERSION,
                PRISM_SEXTANT_CALIBRATION_ID,
                "1",
                "Откалибровать призматический секстант",
                "Закрепить карту невидимого спектра и повысить точность прибора.",
                inventoryContent.require(StarterInventoryContent.PRISM_SEXTANT_ID),
                1,
                2,
                UniqueItemRarity.UNCOMMON,
                UniqueItemRarity.RARE,
                List.of(
                        new CraftingIngredientDefinition(
                                inventoryContent.require(
                                        StarterInventoryContent.ECHO_THREAD_ID
                                ),
                                2
                        ),
                        new CraftingIngredientDefinition(
                                inventoryContent.require(
                                        StarterInventoryContent.PRISM_DUST_ID
                                ),
                                1
                        ),
                        new CraftingIngredientDefinition(
                                inventoryContent.require(
                                        StarterInventoryContent.ION_BLOOM_ID
                                ),
                                1
                        )
                )
        );
    }

    public StarterItemUpgradeContent() {
        this(new StarterInventoryContent());
    }

    public ItemUpgradeDefinition require(
            String upgradeId,
            String activeExpeditionContentVersion
    ) {
        if (!PRISM_SEXTANT_CALIBRATION_ID.equals(upgradeId)
                || !StarterExpeditionContent.supportsPrismSextantRoute(
                        activeExpeditionContentVersion
                )) {
            throw new ItemUpgradeNotFoundException(upgradeId);
        }
        return prismSextantCalibration;
    }

    public List<ItemUpgradeDefinition> upgrades(
            String activeExpeditionContentVersion
    ) {
        return StarterExpeditionContent.supportsPrismSextantRoute(
                activeExpeditionContentVersion
        ) ? List.of(prismSextantCalibration) : List.of();
    }
}
