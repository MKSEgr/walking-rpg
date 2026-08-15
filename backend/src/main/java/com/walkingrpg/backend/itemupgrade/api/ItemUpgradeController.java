package com.walkingrpg.backend.itemupgrade.api;

import com.walkingrpg.backend.itemupgrade.application.ItemUpgradeCommandFactory;
import com.walkingrpg.backend.itemupgrade.application.ItemUpgradeService;
import com.walkingrpg.backend.itemupgrade.domain.ItemUpgradeResult;
import com.walkingrpg.backend.security.RequestIdentityProvider;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/item-upgrades")
public class ItemUpgradeController {

    private final ItemUpgradeCommandFactory commandFactory;
    private final ItemUpgradeService service;
    private final RequestIdentityProvider identityProvider;

    public ItemUpgradeController(
            ItemUpgradeCommandFactory commandFactory,
            ItemUpgradeService service,
            RequestIdentityProvider identityProvider
    ) {
        this.commandFactory = commandFactory;
        this.service = service;
        this.identityProvider = identityProvider;
    }

    @PostMapping("/{upgradeId}/apply")
    public ItemUpgradeResponse upgrade(
            @PathVariable String upgradeId,
            @Valid @RequestBody ItemUpgradeRequest request
    ) {
        ItemUpgradeResult result = service.upgrade(commandFactory.create(
                identityProvider.requireIdentity().userId(),
                upgradeId,
                request
        ));
        return new ItemUpgradeResponse(
                result.contentVersion(),
                result.upgradeId(),
                result.upgradeVersion(),
                result.upgradeName(),
                result.consumedIngredients().stream()
                        .map(ingredient -> new ItemUpgradeIngredientResponse(
                                ingredient.itemId(),
                                ingredient.name(),
                                ingredient.quantityConsumed(),
                                ingredient.quantityAfter(),
                                ingredient.version()
                        ))
                        .toList(),
                new UpgradedUniqueItemResponse(
                        result.upgradedItem().itemInstanceId(),
                        result.upgradedItem().itemId(),
                        result.upgradedItem().name(),
                        result.upgradedItem().description(),
                        result.upgradedItem().previousLevel(),
                        result.upgradedItem().upgradeLevel(),
                        result.upgradedItem().rarity().name(),
                        result.upgradedItem().upgradedAt()
                ),
                result.serverTime()
        );
    }
}
