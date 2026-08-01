package com.walkingrpg.backend.crafting.api;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import com.walkingrpg.backend.crafting.application.CraftingCommandFactory;
import com.walkingrpg.backend.crafting.application.CraftingService;
import com.walkingrpg.backend.crafting.application.InsufficientCraftingMaterialsException;
import com.walkingrpg.backend.crafting.application.StarterCraftingContent;
import com.walkingrpg.backend.crafting.domain.CraftedUniqueItemResult;
import com.walkingrpg.backend.crafting.domain.CraftingIngredientResult;
import com.walkingrpg.backend.crafting.domain.CraftingMaterialShortage;
import com.walkingrpg.backend.crafting.domain.CraftingResult;
import com.walkingrpg.backend.expedition.application.PendingEventResultException;
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

class CraftingControllerTest {

    private static final Instant NOW = Instant.parse("2026-08-01T08:00:00Z");

    private CraftingService service;
    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        service = mock(CraftingService.class);
        CraftingController controller = new CraftingController(
                new CraftingCommandFactory(),
                service,
                FixedRequestIdentityProvider.user("user-1")
        );
        mockMvc = MockMvcBuilders.standaloneSetup(controller)
                .setControllerAdvice(new ApiExceptionHandler())
                .build();
    }

    @Test
    void shouldReturnCraftedUniqueItem() throws Exception {
        UUID itemInstanceId = UUID.fromString(
                "11111111-2222-3333-4444-555555555555"
        );
        when(service.craft(any())).thenReturn(new CraftingResult(
                StarterCraftingContent.CONTENT_VERSION,
                StarterCraftingContent.RESONANCE_COMPASS_RECIPE_ID,
                "1",
                "Собрать резонансный компас",
                List.of(
                        new CraftingIngredientResult(
                                "echo-thread",
                                "Нить эха",
                                1,
                                0,
                                2
                        ),
                        new CraftingIngredientResult(
                                "lumen-shard",
                                "Люминовый осколок",
                                2,
                                1,
                                3
                        )
                ),
                new CraftedUniqueItemResult(
                        itemInstanceId,
                        "resonance-compass",
                        "Резонансный компас",
                        "Уникальный прибор.",
                        1,
                        NOW
                ),
                NOW
        ));

        mockMvc.perform(post(
                        "/api/v1/crafting/recipes/resonance-compass-v1/craft"
                )
                        .contentType("application/json")
                        .content("{\"idempotencyKey\":\"craft-1\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.recipeId")
                        .value("resonance-compass-v1"))
                .andExpect(jsonPath("$.consumedIngredients.length()")
                        .value(2))
                .andExpect(jsonPath("$.craftedItem.itemInstanceId")
                        .value(itemInstanceId.toString()))
                .andExpect(jsonPath("$.craftedItem.itemId")
                        .value("resonance-compass"));
    }

    @Test
    void shouldReturnStableInsufficientMaterialsError() throws Exception {
        when(service.craft(any())).thenThrow(
                new InsufficientCraftingMaterialsException(List.of(
                        new CraftingMaterialShortage(
                                "lumen-shard",
                                2,
                                1
                        )
                ))
        );

        mockMvc.perform(post(
                        "/api/v1/crafting/recipes/resonance-compass-v1/craft"
                )
                        .contentType("application/json")
                        .content("{\"idempotencyKey\":\"craft-1\"}"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("INSUFFICIENT_MATERIALS"))
                .andExpect(jsonPath("$.details.shortages[0].itemId")
                        .value("lumen-shard"))
                .andExpect(jsonPath("$.details.shortages[0].requiredQuantity")
                        .value(2))
                .andExpect(jsonPath("$.traceId").isNotEmpty());
    }

    @Test
    void shouldRequirePendingEventResultAcknowledgementBeforeNewCraft()
            throws Exception {
        UUID receiptId = UUID.fromString(
                "22222222-2222-2222-2222-222222222222"
        );
        when(service.craft(any())).thenThrow(
                new PendingEventResultException(receiptId, "signal-source-v1")
        );

        mockMvc.perform(post(
                        "/api/v1/crafting/recipes/resonance-compass-v1/craft"
                )
                        .contentType("application/json")
                        .content("{\"idempotencyKey\":\"craft-while-pending\"}"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code")
                        .value("EVENT_RESULT_ACKNOWLEDGEMENT_REQUIRED"))
                .andExpect(jsonPath("$.details.receiptId")
                        .value(receiptId.toString()))
                .andExpect(jsonPath("$.traceId").isNotEmpty());
    }
}
