package com.walkingrpg.backend.crafting.infrastructure;

import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import com.walkingrpg.backend.account.application.AccountDeletionRegistry;
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
import com.walkingrpg.backend.operations.JdbcStatementTimeouts;
import org.springframework.jdbc.core.ConnectionCallback;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class JdbcCraftingRepository implements CraftingRepository {

    private static final String LOCK_SQL = """
            SELECT pg_advisory_xact_lock(hashtextextended(?, 37))
            """;
    private static final String CRAFT_REASON = "CRAFTING_INGREDIENT_CONSUMED";
    private static final String CRAFT_SOURCE_TYPE = "CRAFTING_COMMAND";

    private final JdbcTemplate jdbcTemplate;
    private final AccountDeletionRegistry accountDeletionRegistry;

    public JdbcCraftingRepository(
            JdbcTemplate jdbcTemplate,
            AccountDeletionRegistry accountDeletionRegistry
    ) {
        this.jdbcTemplate = jdbcTemplate;
        this.accountDeletionRegistry = accountDeletionRegistry;
    }

    @Override
    public void acquireLock(String userId) {
        accountDeletionRegistry.requireActive(userId);
        jdbcTemplate.execute((ConnectionCallback<Void>) connection -> {
            try (PreparedStatement statement = connection.prepareStatement(LOCK_SQL)) {
                JdbcStatementTimeouts.apply(jdbcTemplate, statement);
                statement.setString(1, userId);
                statement.execute();
            }
            return null;
        });
    }

    @Override
    public Optional<ProcessedCraftingCommand> findProcessed(
            CraftingIdempotencyScope scope
    ) {
        List<ProcessedRow> rows = jdbcTemplate.query("""
                SELECT request_fingerprint,
                       content_version,
                       recipe_version,
                       recipe_name,
                       item_instance_id,
                       result_item_id,
                       result_item_name,
                       result_item_description,
                       result_item_version,
                       crafted_at,
                       server_time
                FROM processed_crafting_command
                WHERE user_id = ?
                  AND recipe_id = ?
                  AND idempotency_key = ?
                """, this::mapProcessedRow,
                scope.userId(), scope.recipeId(), scope.idempotencyKey());
        if (rows.isEmpty()) {
            return Optional.empty();
        }
        ProcessedRow row = rows.getFirst();
        List<CraftingIngredientResult> ingredients = findProcessedIngredients(scope);
        return Optional.of(new ProcessedCraftingCommand(
                row.requestFingerprint(),
                new CraftingResult(
                        row.contentVersion(),
                        scope.recipeId(),
                        row.recipeVersion(),
                        row.recipeName(),
                        ingredients,
                        new CraftedUniqueItemResult(
                                row.itemInstanceId(),
                                row.itemId(),
                                row.itemName(),
                                row.itemDescription(),
                                row.itemVersion(),
                                row.craftedAt()
                        ),
                        row.serverTime()
                )
        ));
    }

    @Override
    public CraftingResult createUniqueItem(
            CraftingIdempotencyScope scope,
            String requestFingerprint,
            CraftingRecipeDefinition recipe,
            Instant serverTime
    ) {
        requireUniqueItemAbsent(scope.userId(), recipe);
        List<LockedIngredient> locked = lockIngredients(scope.userId(), recipe);
        List<CraftingMaterialShortage> shortages = locked.stream()
                .filter(value -> value.availableQuantity() < value.definition().quantity())
                .map(value -> new CraftingMaterialShortage(
                        value.definition().item().itemId(),
                        value.definition().quantity(),
                        value.availableQuantity()
                ))
                .toList();
        if (!shortages.isEmpty()) {
            throw new InsufficientCraftingMaterialsException(shortages);
        }

        List<CraftingIngredientResult> consumed = new ArrayList<>();
        for (LockedIngredient ingredient : locked) {
            CraftingIngredientResult result = consumeIngredient(
                    scope,
                    ingredient.definition(),
                    serverTime
            );
            appendConsumptionLedger(scope, result, serverTime);
            consumed.add(result);
        }

        UUID itemInstanceId = UUID.randomUUID();
        CraftedUniqueItemResult craftedItem = new CraftedUniqueItemResult(
                itemInstanceId,
                recipe.resultItem().itemId(),
                recipe.resultItem().name(),
                recipe.resultItem().description(),
                1,
                serverTime
        );
        insertUniqueItem(scope.userId(), recipe, craftedItem);
        CraftingResult result = new CraftingResult(
                recipe.contentVersion(),
                recipe.recipeId(),
                recipe.recipeVersion(),
                recipe.name(),
                consumed,
                craftedItem,
                serverTime
        );
        saveProcessed(scope, requestFingerprint, result);
        return result;
    }

    private void requireUniqueItemAbsent(
            String userId,
            CraftingRecipeDefinition recipe
    ) {
        Integer count = jdbcTemplate.queryForObject("""
                SELECT count(*)
                FROM unique_inventory_item
                WHERE user_id = ?
                  AND item_id = ?
                """, Integer.class, userId, recipe.resultItem().itemId());
        if (count != null && count > 0) {
            throw new CraftingStateConflictException(
                    recipe.recipeId(),
                    recipe.resultItem().itemId()
            );
        }
    }

    private List<LockedIngredient> lockIngredients(
            String userId,
            CraftingRecipeDefinition recipe
    ) {
        List<CraftingIngredientDefinition> definitions = recipe.ingredients()
                .stream()
                .sorted(Comparator.comparing(value -> value.item().itemId()))
                .toList();
        List<LockedIngredient> locked = new ArrayList<>();
        for (CraftingIngredientDefinition definition : definitions) {
            List<InventoryRow> rows = jdbcTemplate.query("""
                    SELECT quantity, version
                    FROM inventory_stack
                    WHERE user_id = ?
                      AND item_id = ?
                    FOR UPDATE
                    """, (resultSet, rowNumber) -> new InventoryRow(
                    resultSet.getLong("quantity"),
                    resultSet.getLong("version")
            ), userId, definition.item().itemId());
            long available = rows.isEmpty() ? 0 : rows.getFirst().quantity();
            locked.add(new LockedIngredient(definition, available));
        }
        return List.copyOf(locked);
    }

    private CraftingIngredientResult consumeIngredient(
            CraftingIdempotencyScope scope,
            CraftingIngredientDefinition ingredient,
            Instant serverTime
    ) {
        List<CraftingIngredientResult> updated = jdbcTemplate.query("""
                UPDATE inventory_stack
                SET quantity = quantity - ?,
                    version = version + 1,
                    updated_at = ?
                WHERE user_id = ?
                  AND item_id = ?
                  AND quantity >= ?
                RETURNING item_id, quantity, version
                """, (resultSet, rowNumber) -> new CraftingIngredientResult(
                resultSet.getString("item_id"),
                ingredient.item().name(),
                ingredient.quantity(),
                resultSet.getLong("quantity"),
                resultSet.getLong("version")
        ),
                ingredient.quantity(),
                Timestamp.from(serverTime),
                scope.userId(),
                ingredient.item().itemId(),
                ingredient.quantity()
        );
        return updated.stream()
                .findFirst()
                .orElseThrow(() -> new IllegalStateException(
                        "Inventory stack изменился после блокировки"
                ));
    }

    private void appendConsumptionLedger(
            CraftingIdempotencyScope scope,
            CraftingIngredientResult ingredient,
            Instant serverTime
    ) {
        jdbcTemplate.update("""
                INSERT INTO inventory_ledger (
                    ledger_entry_id,
                    user_id,
                    item_id,
                    quantity_delta,
                    quantity_after,
                    inventory_version,
                    reason_code,
                    source_type,
                    source_key,
                    created_at
                )
                VALUES (gen_random_uuid(), ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                scope.userId(),
                ingredient.itemId(),
                -ingredient.quantityConsumed(),
                ingredient.quantityAfter(),
                ingredient.version(),
                CRAFT_REASON,
                CRAFT_SOURCE_TYPE,
                sourceKey(scope, ingredient.itemId()),
                Timestamp.from(serverTime)
        );
    }

    private void insertUniqueItem(
            String userId,
            CraftingRecipeDefinition recipe,
            CraftedUniqueItemResult item
    ) {
        jdbcTemplate.update("""
                INSERT INTO unique_inventory_item (
                    item_instance_id,
                    user_id,
                    item_id,
                    recipe_id,
                    recipe_version,
                    version,
                    crafted_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                item.itemInstanceId(),
                userId,
                item.itemId(),
                recipe.recipeId(),
                recipe.recipeVersion(),
                item.version(),
                Timestamp.from(item.craftedAt())
        );
    }

    private void saveProcessed(
            CraftingIdempotencyScope scope,
            String requestFingerprint,
            CraftingResult result
    ) {
        CraftedUniqueItemResult item = result.craftedItem();
        jdbcTemplate.update("""
                INSERT INTO processed_crafting_command (
                    user_id,
                    recipe_id,
                    idempotency_key,
                    request_fingerprint,
                    content_version,
                    recipe_version,
                    recipe_name,
                    item_instance_id,
                    result_item_id,
                    result_item_name,
                    result_item_description,
                    result_item_version,
                    crafted_at,
                    server_time,
                    created_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, now())
                """,
                scope.userId(),
                scope.recipeId(),
                scope.idempotencyKey(),
                requestFingerprint,
                result.contentVersion(),
                result.recipeVersion(),
                result.recipeName(),
                item.itemInstanceId(),
                item.itemId(),
                item.name(),
                item.description(),
                item.version(),
                Timestamp.from(item.craftedAt()),
                Timestamp.from(result.serverTime())
        );
        for (CraftingIngredientResult ingredient : result.consumedIngredients()) {
            jdbcTemplate.update("""
                    INSERT INTO processed_crafting_ingredient (
                        user_id,
                        recipe_id,
                        idempotency_key,
                        item_id,
                        item_name,
                        quantity_consumed,
                        quantity_after,
                        inventory_version
                    )
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    scope.userId(),
                    scope.recipeId(),
                    scope.idempotencyKey(),
                    ingredient.itemId(),
                    ingredient.name(),
                    ingredient.quantityConsumed(),
                    ingredient.quantityAfter(),
                    ingredient.version()
            );
        }
    }

    private List<CraftingIngredientResult> findProcessedIngredients(
            CraftingIdempotencyScope scope
    ) {
        return jdbcTemplate.query("""
                SELECT item_id,
                       item_name,
                       quantity_consumed,
                       quantity_after,
                       inventory_version
                FROM processed_crafting_ingredient
                WHERE user_id = ?
                  AND recipe_id = ?
                  AND idempotency_key = ?
                ORDER BY item_id
                """, (resultSet, rowNumber) -> new CraftingIngredientResult(
                resultSet.getString("item_id"),
                resultSet.getString("item_name"),
                resultSet.getLong("quantity_consumed"),
                resultSet.getLong("quantity_after"),
                resultSet.getLong("inventory_version")
        ), scope.userId(), scope.recipeId(), scope.idempotencyKey());
    }

    private ProcessedRow mapProcessedRow(
            ResultSet resultSet,
            int rowNumber
    ) throws SQLException {
        return new ProcessedRow(
                resultSet.getString("request_fingerprint"),
                resultSet.getString("content_version"),
                resultSet.getString("recipe_version"),
                resultSet.getString("recipe_name"),
                resultSet.getObject("item_instance_id", UUID.class),
                resultSet.getString("result_item_id"),
                resultSet.getString("result_item_name"),
                resultSet.getString("result_item_description"),
                resultSet.getLong("result_item_version"),
                resultSet.getTimestamp("crafted_at").toInstant(),
                resultSet.getTimestamp("server_time").toInstant()
        );
    }

    private String sourceKey(
            CraftingIdempotencyScope scope,
            String itemId
    ) {
        return lengthPrefixed(scope.recipeId())
                + lengthPrefixed(scope.idempotencyKey())
                + lengthPrefixed(itemId);
    }

    private String lengthPrefixed(String value) {
        return value.length() + ":" + value + ";";
    }

    private record InventoryRow(long quantity, long version) {
    }

    private record LockedIngredient(
            CraftingIngredientDefinition definition,
            long availableQuantity
    ) {
    }

    private record ProcessedRow(
            String requestFingerprint,
            String contentVersion,
            String recipeVersion,
            String recipeName,
            UUID itemInstanceId,
            String itemId,
            String itemName,
            String itemDescription,
            long itemVersion,
            Instant craftedAt,
            Instant serverTime
    ) {
    }
}
