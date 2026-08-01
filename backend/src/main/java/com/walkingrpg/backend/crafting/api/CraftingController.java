package com.walkingrpg.backend.crafting.api;

import com.walkingrpg.backend.crafting.application.CraftingCommandFactory;
import com.walkingrpg.backend.crafting.application.CraftingService;
import com.walkingrpg.backend.crafting.domain.CraftingResult;
import com.walkingrpg.backend.security.RequestIdentityProvider;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/crafting/recipes")
public class CraftingController {

    private final CraftingCommandFactory commandFactory;
    private final CraftingService service;
    private final RequestIdentityProvider identityProvider;

    public CraftingController(
            CraftingCommandFactory commandFactory,
            CraftingService service,
            RequestIdentityProvider identityProvider
    ) {
        this.commandFactory = commandFactory;
        this.service = service;
        this.identityProvider = identityProvider;
    }

    @PostMapping("/{recipeId}/craft")
    public CraftingResponse craft(
            @PathVariable String recipeId,
            @Valid @RequestBody CraftingRequest request
    ) {
        CraftingResult result = service.craft(commandFactory.create(
                identityProvider.requireIdentity().userId(),
                recipeId,
                request
        ));
        return new CraftingResponse(
                result.contentVersion(),
                result.recipeId(),
                result.recipeVersion(),
                result.recipeName(),
                result.consumedIngredients().stream()
                        .map(ingredient -> new CraftingIngredientResponse(
                                ingredient.itemId(),
                                ingredient.name(),
                                ingredient.quantityConsumed(),
                                ingredient.quantityAfter(),
                                ingredient.version()
                        ))
                        .toList(),
                new CraftedUniqueItemResponse(
                        result.craftedItem().itemInstanceId(),
                        result.craftedItem().itemId(),
                        result.craftedItem().name(),
                        result.craftedItem().description(),
                        result.craftedItem().version(),
                        result.craftedItem().craftedAt()
                ),
                result.serverTime()
        );
    }
}
