package com.walkingrpg.backend.crafting.application;

import java.util.List;
import java.util.Map;

import com.walkingrpg.backend.crafting.domain.CraftingIngredientDefinition;
import com.walkingrpg.backend.crafting.domain.CraftingRecipeDefinition;
import com.walkingrpg.backend.expedition.application.StarterExpeditionContent;
import com.walkingrpg.backend.inventory.application.StarterInventoryContent;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

@Component
public class StarterCraftingContent {

    public static final String CONTENT_VERSION = "crafting-v1";
    public static final String PRISM_CONTENT_VERSION = "crafting-v2";
    public static final String RESONANCE_COMPASS_RECIPE_ID =
            "resonance-compass-v1";
    public static final String PRISM_SEXTANT_RECIPE_ID = "prism-sextant-v1";

    private final Map<String, CraftingRecipeDefinition> recipes;

    @Autowired
    public StarterCraftingContent(StarterInventoryContent inventoryContent) {
        CraftingRecipeDefinition resonanceCompass = new CraftingRecipeDefinition(
                CONTENT_VERSION,
                RESONANCE_COMPASS_RECIPE_ID,
                "1",
                "Собрать резонансный компас",
                "Соединить световое ядро с живой нитью маршрута.",
                List.of(
                        new CraftingIngredientDefinition(
                                inventoryContent.require(
                                        StarterInventoryContent.LUMEN_SHARD_ID
                                ),
                                2
                        ),
                        new CraftingIngredientDefinition(
                                inventoryContent.require(
                                        StarterInventoryContent.ECHO_THREAD_ID
                                ),
                                1
                        )
                ),
                inventoryContent.require(
                        StarterInventoryContent.RESONANCE_COMPASS_ID
                )
        );
        CraftingRecipeDefinition prismSextant = new CraftingRecipeDefinition(
                PRISM_CONTENT_VERSION,
                PRISM_SEXTANT_RECIPE_ID,
                "1",
                "Собрать призматический секстант",
                "Свести пыль, ионный заряд и свет рассвета в карту скрытого спектра.",
                List.of(
                        new CraftingIngredientDefinition(
                                inventoryContent.require(
                                        StarterInventoryContent.PRISM_DUST_ID
                                ),
                                2
                        ),
                        new CraftingIngredientDefinition(
                                inventoryContent.require(
                                        StarterInventoryContent.ION_BLOOM_ID
                                ),
                                1
                        ),
                        new CraftingIngredientDefinition(
                                inventoryContent.require(
                                        StarterInventoryContent.DAWN_FRAGMENT_ID
                                ),
                                1
                        )
                ),
                inventoryContent.require(StarterInventoryContent.PRISM_SEXTANT_ID)
        );
        this.recipes = Map.of(
                resonanceCompass.recipeId(), resonanceCompass,
                prismSextant.recipeId(), prismSextant
        );
    }

    public StarterCraftingContent() {
        this(new StarterInventoryContent());
    }

    public CraftingRecipeDefinition require(String recipeId) {
        CraftingRecipeDefinition recipe = recipes.get(recipeId);
        if (recipe == null) {
            throw new CraftingRecipeNotFoundException(recipeId);
        }
        return recipe;
    }

    public CraftingRecipeDefinition require(
            String recipeId,
            String activeExpeditionContentVersion
    ) {
        CraftingRecipeDefinition recipe = require(recipeId);
        if (PRISM_SEXTANT_RECIPE_ID.equals(recipeId)
                && !StarterExpeditionContent.supportsPrismSextantRoute(
                        activeExpeditionContentVersion
                )) {
            throw new CraftingRecipeNotFoundException(recipeId);
        }
        return recipe;
    }

    public List<CraftingRecipeDefinition> recipes() {
        return recipes.values().stream()
                .sorted((left, right) -> left.recipeId().compareTo(right.recipeId()))
                .toList();
    }

    public List<CraftingRecipeDefinition> recipes(
            String activeExpeditionContentVersion
    ) {
        return recipes().stream()
                .filter(recipe -> !PRISM_SEXTANT_RECIPE_ID.equals(
                        recipe.recipeId()
                ) || StarterExpeditionContent.supportsPrismSextantRoute(
                                activeExpeditionContentVersion
                        ))
                .toList();
    }
}
