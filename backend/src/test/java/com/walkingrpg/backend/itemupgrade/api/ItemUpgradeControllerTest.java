package com.walkingrpg.backend.itemupgrade.api;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import com.walkingrpg.backend.crafting.domain.CraftingIngredientResult;
import com.walkingrpg.backend.inventory.domain.UniqueItemRarity;
import com.walkingrpg.backend.itemupgrade.application.ItemUpgradeCommandFactory;
import com.walkingrpg.backend.itemupgrade.application.ItemUpgradeService;
import com.walkingrpg.backend.itemupgrade.application.ItemUpgradeStateConflictException;
import com.walkingrpg.backend.itemupgrade.application.StarterItemUpgradeContent;
import com.walkingrpg.backend.itemupgrade.domain.ItemUpgradeResult;
import com.walkingrpg.backend.itemupgrade.domain.UpgradedUniqueItemResult;
import com.walkingrpg.backend.security.FixedRequestIdentityProvider;
import com.walkingrpg.backend.shared.api.ApiExceptionHandler;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class ItemUpgradeControllerTest {

    private static final Instant NOW = Instant.parse("2026-08-15T08:00:00Z");
    private static final UUID ITEM_INSTANCE_ID = UUID.fromString(
            "11111111-2222-3333-4444-555555555555"
    );

    private ItemUpgradeService service;
    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        service = mock(ItemUpgradeService.class);
        ItemUpgradeController controller = new ItemUpgradeController(
                new ItemUpgradeCommandFactory(),
                service,
                FixedRequestIdentityProvider.user("user-1")
        );
        mockMvc = MockMvcBuilders.standaloneSetup(controller)
                .setControllerAdvice(new ApiExceptionHandler())
                .build();
    }

    @Test
    void shouldReturnAuthoritativeUpgradedItem() throws Exception {
        when(service.upgrade(any())).thenReturn(result());

        mockMvc.perform(post("/api/v1/item-upgrades/"
                        + StarterItemUpgradeContent.PRISM_SEXTANT_CALIBRATION_ID
                        + "/apply")
                        .contentType("application/json")
                        .content("{\"idempotencyKey\":\"upgrade-1\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.contentVersion")
                        .value(StarterItemUpgradeContent.CONTENT_VERSION))
                .andExpect(jsonPath("$.consumedIngredients.length()").value(3))
                .andExpect(jsonPath("$.upgradedItem.itemInstanceId")
                        .value(ITEM_INSTANCE_ID.toString()))
                .andExpect(jsonPath("$.upgradedItem.previousLevel").value(1))
                .andExpect(jsonPath("$.upgradedItem.upgradeLevel").value(2))
                .andExpect(jsonPath("$.upgradedItem.rarity").value("RARE"));
    }

    @Test
    void shouldReturnStableStateConflict() throws Exception {
        when(service.upgrade(any())).thenThrow(
                new ItemUpgradeStateConflictException(
                        StarterItemUpgradeContent.PRISM_SEXTANT_CALIBRATION_ID,
                        "prism-sextant",
                        "TARGET_NOT_OWNED"
                )
        );

        mockMvc.perform(post("/api/v1/item-upgrades/"
                        + StarterItemUpgradeContent.PRISM_SEXTANT_CALIBRATION_ID
                        + "/apply")
                        .contentType("application/json")
                        .content("{\"idempotencyKey\":\"upgrade-1\"}"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code")
                        .value("ITEM_UPGRADE_STATE_CONFLICT"))
                .andExpect(jsonPath("$.details.itemId")
                        .value("prism-sextant"))
                .andExpect(jsonPath("$.details.reason")
                        .value("TARGET_NOT_OWNED"));
    }

    private ItemUpgradeResult result() {
        return new ItemUpgradeResult(
                StarterItemUpgradeContent.CONTENT_VERSION,
                StarterItemUpgradeContent.PRISM_SEXTANT_CALIBRATION_ID,
                "1",
                "Откалибровать призматический секстант",
                List.of(
                        new CraftingIngredientResult(
                                "echo-thread", "Нить эха", 2, 0, 2
                        ),
                        new CraftingIngredientResult(
                                "ion-bloom", "Ионный цветок", 1, 0, 2
                        ),
                        new CraftingIngredientResult(
                                "prism-dust", "Призматическая пыль", 1, 0, 2
                        )
                ),
                new UpgradedUniqueItemResult(
                        ITEM_INSTANCE_ID,
                        "prism-sextant",
                        "Призматический секстант",
                        "Прибор для чтения преломлённых маршрутов.",
                        1,
                        2,
                        UniqueItemRarity.RARE,
                        NOW
                ),
                NOW
        );
    }
}
