package com.walkingrpg.backend.itemupgrade.infrastructure;

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
import com.walkingrpg.backend.crafting.application.InsufficientCraftingMaterialsException;
import com.walkingrpg.backend.crafting.domain.CraftingIngredientDefinition;
import com.walkingrpg.backend.crafting.domain.CraftingIngredientResult;
import com.walkingrpg.backend.crafting.domain.CraftingMaterialShortage;
import com.walkingrpg.backend.inventory.domain.UniqueItemRarity;
import com.walkingrpg.backend.itemupgrade.application.ItemUpgradeStateConflictException;
import com.walkingrpg.backend.itemupgrade.domain.ItemUpgradeDefinition;
import com.walkingrpg.backend.itemupgrade.domain.ItemUpgradeIdempotencyScope;
import com.walkingrpg.backend.itemupgrade.domain.ItemUpgradeResult;
import com.walkingrpg.backend.itemupgrade.domain.ProcessedItemUpgradeCommand;
import com.walkingrpg.backend.itemupgrade.domain.UpgradedUniqueItemResult;
import com.walkingrpg.backend.operations.JdbcStatementTimeouts;
import org.springframework.jdbc.core.ConnectionCallback;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class JdbcItemUpgradeRepository implements ItemUpgradeRepository {

    private static final String LOCK_SQL = """
            SELECT pg_advisory_xact_lock(hashtextextended(?, 37))
            """;
    private static final String UPGRADE_REASON =
            "ITEM_UPGRADE_INGREDIENT_CONSUMED";
    private static final String UPGRADE_SOURCE_TYPE = "ITEM_UPGRADE_COMMAND";

    private final JdbcTemplate jdbcTemplate;
    private final AccountDeletionRegistry accountDeletionRegistry;

    public JdbcItemUpgradeRepository(
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
    public Optional<ProcessedItemUpgradeCommand> findProcessed(
            ItemUpgradeIdempotencyScope scope
    ) {
        List<ProcessedRow> rows = jdbcTemplate.query("""
                SELECT request_fingerprint,
                       content_version,
                       upgrade_version,
                       upgrade_name,
                       item_instance_id,
                       item_id,
                       item_name,
                       item_description,
                       previous_level,
                       result_level,
                       result_rarity,
                       upgraded_at,
                       server_time
                FROM processed_item_upgrade_command
                WHERE user_id = ?
                  AND upgrade_id = ?
                  AND idempotency_key = ?
                """, this::mapProcessedRow,
                scope.userId(), scope.upgradeId(), scope.idempotencyKey());
        if (rows.isEmpty()) {
            return Optional.empty();
        }
        ProcessedRow row = rows.getFirst();
        return Optional.of(new ProcessedItemUpgradeCommand(
                row.requestFingerprint(),
                new ItemUpgradeResult(
                        row.contentVersion(),
                        scope.upgradeId(),
                        row.upgradeVersion(),
                        row.upgradeName(),
                        findProcessedIngredients(scope),
                        new UpgradedUniqueItemResult(
                                row.itemInstanceId(),
                                row.itemId(),
                                row.itemName(),
                                row.itemDescription(),
                                row.previousLevel(),
                                row.resultLevel(),
                                UniqueItemRarity.valueOf(row.resultRarity()),
                                row.upgradedAt()
                        ),
                        row.serverTime()
                )
        ));
    }

    @Override
    public ItemUpgradeResult upgrade(
            ItemUpgradeIdempotencyScope scope,
            String requestFingerprint,
            ItemUpgradeDefinition definition,
            Instant serverTime
    ) {
        UniqueItemRow item = lockTargetItem(scope.userId(), definition);
        if (item.level() != definition.requiredLevel()) {
            throw new ItemUpgradeStateConflictException(
                    definition.upgradeId(),
                    definition.targetItem().itemId(),
                    item.level() >= definition.resultingLevel()
                            ? "ALREADY_COMPLETED"
                            : "INCOMPATIBLE_LEVEL"
            );
        }

        List<LockedIngredient> locked = lockIngredients(scope.userId(), definition);
        List<CraftingMaterialShortage> shortages = locked.stream()
                .filter(value -> value.availableQuantity()
                        < value.definition().quantity())
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

        UpgradedUniqueItemResult upgradedItem = applyUpgrade(
                scope.userId(),
                definition,
                item,
                serverTime
        );
        ItemUpgradeResult result = new ItemUpgradeResult(
                definition.contentVersion(),
                definition.upgradeId(),
                definition.upgradeVersion(),
                definition.name(),
                consumed,
                upgradedItem,
                serverTime
        );
        saveProcessed(scope, requestFingerprint, result);
        return result;
    }

    private UniqueItemRow lockTargetItem(
            String userId,
            ItemUpgradeDefinition definition
    ) {
        List<UniqueItemRow> rows = jdbcTemplate.query("""
                SELECT item_instance_id, item_id, version, rarity
                FROM unique_inventory_item
                WHERE user_id = ?
                  AND item_id = ?
                FOR UPDATE
                """, (resultSet, rowNumber) -> new UniqueItemRow(
                resultSet.getObject("item_instance_id", UUID.class),
                resultSet.getString("item_id"),
                resultSet.getLong("version"),
                resultSet.getString("rarity")
        ), userId, definition.targetItem().itemId());
        return rows.stream().findFirst().orElseThrow(() ->
                new ItemUpgradeStateConflictException(
                        definition.upgradeId(),
                        definition.targetItem().itemId(),
                        "TARGET_NOT_OWNED"
                )
        );
    }

    private List<LockedIngredient> lockIngredients(
            String userId,
            ItemUpgradeDefinition definition
    ) {
        List<CraftingIngredientDefinition> ingredients = definition.ingredients()
                .stream()
                .sorted(Comparator.comparing(value -> value.item().itemId()))
                .toList();
        List<LockedIngredient> locked = new ArrayList<>();
        for (CraftingIngredientDefinition ingredient : ingredients) {
            List<InventoryRow> rows = jdbcTemplate.query("""
                    SELECT quantity, version
                    FROM inventory_stack
                    WHERE user_id = ?
                      AND item_id = ?
                    FOR UPDATE
                    """, (resultSet, rowNumber) -> new InventoryRow(
                    resultSet.getLong("quantity"),
                    resultSet.getLong("version")
            ), userId, ingredient.item().itemId());
            long available = rows.isEmpty() ? 0 : rows.getFirst().quantity();
            locked.add(new LockedIngredient(ingredient, available));
        }
        return List.copyOf(locked);
    }

    private CraftingIngredientResult consumeIngredient(
            ItemUpgradeIdempotencyScope scope,
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
        return updated.stream().findFirst().orElseThrow(() ->
                new IllegalStateException(
                        "Inventory stack изменился после блокировки"
                )
        );
    }

    private void appendConsumptionLedger(
            ItemUpgradeIdempotencyScope scope,
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
                UPGRADE_REASON,
                UPGRADE_SOURCE_TYPE,
                sourceKey(scope, ingredient.itemId()),
                Timestamp.from(serverTime)
        );
    }

    private UpgradedUniqueItemResult applyUpgrade(
            String userId,
            ItemUpgradeDefinition definition,
            UniqueItemRow item,
            Instant serverTime
    ) {
        List<UpgradedUniqueItemResult> rows = jdbcTemplate.query("""
                UPDATE unique_inventory_item
                SET version = ?,
                    rarity = ?,
                    upgraded_at = ?
                WHERE user_id = ?
                  AND item_instance_id = ?
                  AND version = ?
                RETURNING item_instance_id, version, rarity, upgraded_at
                """, (resultSet, rowNumber) -> new UpgradedUniqueItemResult(
                resultSet.getObject("item_instance_id", UUID.class),
                definition.targetItem().itemId(),
                definition.targetItem().name(),
                definition.targetItem().description(),
                definition.requiredLevel(),
                resultSet.getLong("version"),
                UniqueItemRarity.valueOf(resultSet.getString("rarity")),
                resultSet.getTimestamp("upgraded_at").toInstant()
        ),
                definition.resultingLevel(),
                definition.resultingRarity().name(),
                Timestamp.from(serverTime),
                userId,
                item.itemInstanceId(),
                definition.requiredLevel()
        );
        return rows.stream().findFirst().orElseThrow(() ->
                new IllegalStateException("Unique item изменился после блокировки")
        );
    }

    private void saveProcessed(
            ItemUpgradeIdempotencyScope scope,
            String requestFingerprint,
            ItemUpgradeResult result
    ) {
        UpgradedUniqueItemResult item = result.upgradedItem();
        jdbcTemplate.update("""
                INSERT INTO processed_item_upgrade_command (
                    user_id,
                    upgrade_id,
                    idempotency_key,
                    request_fingerprint,
                    content_version,
                    upgrade_version,
                    upgrade_name,
                    item_instance_id,
                    item_id,
                    item_name,
                    item_description,
                    previous_level,
                    result_level,
                    result_rarity,
                    upgraded_at,
                    server_time,
                    created_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, now())
                """,
                scope.userId(),
                scope.upgradeId(),
                scope.idempotencyKey(),
                requestFingerprint,
                result.contentVersion(),
                result.upgradeVersion(),
                result.upgradeName(),
                item.itemInstanceId(),
                item.itemId(),
                item.name(),
                item.description(),
                item.previousLevel(),
                item.upgradeLevel(),
                item.rarity().name(),
                Timestamp.from(item.upgradedAt()),
                Timestamp.from(result.serverTime())
        );
        for (CraftingIngredientResult ingredient : result.consumedIngredients()) {
            jdbcTemplate.update("""
                    INSERT INTO processed_item_upgrade_ingredient (
                        user_id,
                        upgrade_id,
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
                    scope.upgradeId(),
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
            ItemUpgradeIdempotencyScope scope
    ) {
        return jdbcTemplate.query("""
                SELECT item_id,
                       item_name,
                       quantity_consumed,
                       quantity_after,
                       inventory_version
                FROM processed_item_upgrade_ingredient
                WHERE user_id = ?
                  AND upgrade_id = ?
                  AND idempotency_key = ?
                ORDER BY item_id
                """, (resultSet, rowNumber) -> new CraftingIngredientResult(
                resultSet.getString("item_id"),
                resultSet.getString("item_name"),
                resultSet.getLong("quantity_consumed"),
                resultSet.getLong("quantity_after"),
                resultSet.getLong("inventory_version")
        ), scope.userId(), scope.upgradeId(), scope.idempotencyKey());
    }

    private ProcessedRow mapProcessedRow(ResultSet resultSet, int rowNumber)
            throws SQLException {
        return new ProcessedRow(
                resultSet.getString("request_fingerprint"),
                resultSet.getString("content_version"),
                resultSet.getString("upgrade_version"),
                resultSet.getString("upgrade_name"),
                resultSet.getObject("item_instance_id", UUID.class),
                resultSet.getString("item_id"),
                resultSet.getString("item_name"),
                resultSet.getString("item_description"),
                resultSet.getLong("previous_level"),
                resultSet.getLong("result_level"),
                resultSet.getString("result_rarity"),
                resultSet.getTimestamp("upgraded_at").toInstant(),
                resultSet.getTimestamp("server_time").toInstant()
        );
    }

    private String sourceKey(
            ItemUpgradeIdempotencyScope scope,
            String itemId
    ) {
        return scope.upgradeId().length()
                + ":"
                + scope.upgradeId()
                + ":"
                + scope.idempotencyKey().length()
                + ":"
                + scope.idempotencyKey()
                + ":"
                + itemId;
    }

    private record UniqueItemRow(
            UUID itemInstanceId,
            String itemId,
            long level,
            String rarity
    ) {
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
            String upgradeVersion,
            String upgradeName,
            UUID itemInstanceId,
            String itemId,
            String itemName,
            String itemDescription,
            long previousLevel,
            long resultLevel,
            String resultRarity,
            Instant upgradedAt,
            Instant serverTime
    ) {
    }
}
