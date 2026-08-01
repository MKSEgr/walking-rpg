package com.walkingrpg.backend.crafting.infrastructure;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import com.walkingrpg.backend.crafting.application.CraftingStateConflictException;
import com.walkingrpg.backend.crafting.application.InsufficientCraftingMaterialsException;
import com.walkingrpg.backend.crafting.domain.CraftedUniqueItemResult;
import com.walkingrpg.backend.crafting.domain.CraftingIdempotencyScope;
import com.walkingrpg.backend.crafting.domain.CraftingIngredientDefinition;
import com.walkingrpg.backend.crafting.domain.CraftingIngredientResult;
import com.walkingrpg.backend.crafting.domain.CraftingMaterialShortage;
import com.walkingrpg.backend.crafting.domain.CraftingRecipeDefinition;
import com.walkingrpg.backend.crafting.domain.CraftingResult;
import com.walkingrpg.backend.crafting.domain.ProcessedCraftingCommand;

public class InMemoryCraftingRepository implements CraftingRepository {

    private final Map<ScopeKey, ProcessedCraftingCommand> processed = new HashMap<>();
    private final Map<ItemKey, StackState> materials = new HashMap<>();
    private final Map<ItemKey, CraftedUniqueItemResult> uniqueItems = new HashMap<>();

    @Override
    public synchronized void acquireLock(String userId) {
        // synchronized methods provide the in-memory test lock.
    }

    @Override
    public synchronized Optional<ProcessedCraftingCommand> findProcessed(
            CraftingIdempotencyScope scope
    ) {
        return Optional.ofNullable(processed.get(ScopeKey.from(scope)));
    }

    @Override
    public synchronized CraftingResult createUniqueItem(
            CraftingIdempotencyScope scope,
            String requestFingerprint,
            CraftingRecipeDefinition recipe,
            Instant serverTime
    ) {
        ItemKey resultKey = new ItemKey(
                scope.userId(),
                recipe.resultItem().itemId()
        );
        if (uniqueItems.containsKey(resultKey)) {
            throw new CraftingStateConflictException(
                    recipe.recipeId(),
                    recipe.resultItem().itemId()
            );
        }
        List<CraftingMaterialShortage> shortages = recipe.ingredients().stream()
                .map(ingredient -> shortage(scope.userId(), ingredient))
                .flatMap(Optional::stream)
                .toList();
        if (!shortages.isEmpty()) {
            throw new InsufficientCraftingMaterialsException(shortages);
        }

        List<CraftingIngredientDefinition> sorted = recipe.ingredients().stream()
                .sorted(Comparator.comparing(value -> value.item().itemId()))
                .toList();
        List<CraftingIngredientResult> consumed = new ArrayList<>();
        for (CraftingIngredientDefinition ingredient : sorted) {
            ItemKey key = new ItemKey(scope.userId(), ingredient.item().itemId());
            StackState current = materials.get(key);
            StackState updated = new StackState(
                    current.quantity() - ingredient.quantity(),
                    current.version() + 1
            );
            materials.put(key, updated);
            consumed.add(new CraftingIngredientResult(
                    ingredient.item().itemId(),
                    ingredient.item().name(),
                    ingredient.quantity(),
                    updated.quantity(),
                    updated.version()
            ));
        }

        CraftedUniqueItemResult item = new CraftedUniqueItemResult(
                UUID.randomUUID(),
                recipe.resultItem().itemId(),
                recipe.resultItem().name(),
                recipe.resultItem().description(),
                1,
                serverTime
        );
        uniqueItems.put(resultKey, item);
        CraftingResult result = new CraftingResult(
                recipe.contentVersion(),
                recipe.recipeId(),
                recipe.recipeVersion(),
                recipe.name(),
                consumed,
                item,
                serverTime
        );
        processed.put(
                ScopeKey.from(scope),
                new ProcessedCraftingCommand(requestFingerprint, result)
        );
        return result;
    }

    public synchronized void putMaterial(
            String userId,
            String itemId,
            long quantity,
            long version
    ) {
        materials.put(new ItemKey(userId, itemId), new StackState(quantity, version));
    }

    public synchronized long materialQuantity(String userId, String itemId) {
        StackState state = materials.get(new ItemKey(userId, itemId));
        return state == null ? 0 : state.quantity();
    }

    private Optional<CraftingMaterialShortage> shortage(
            String userId,
            CraftingIngredientDefinition ingredient
    ) {
        StackState state = materials.get(new ItemKey(
                userId,
                ingredient.item().itemId()
        ));
        long available = state == null ? 0 : state.quantity();
        if (available >= ingredient.quantity()) {
            return Optional.empty();
        }
        return Optional.of(new CraftingMaterialShortage(
                ingredient.item().itemId(),
                ingredient.quantity(),
                available
        ));
    }

    private record ScopeKey(
            String userId,
            String recipeId,
            String idempotencyKey
    ) {
        private static ScopeKey from(CraftingIdempotencyScope scope) {
            return new ScopeKey(
                    scope.userId(),
                    scope.recipeId(),
                    scope.idempotencyKey()
            );
        }
    }

    private record ItemKey(String userId, String itemId) {
    }

    private record StackState(long quantity, long version) {
    }
}
