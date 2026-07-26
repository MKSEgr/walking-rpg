package com.walkingrpg.backend.inventory.application;

import java.util.List;
import java.util.Map;

import com.walkingrpg.backend.inventory.domain.InventoryItemDefinition;
import org.springframework.stereotype.Component;

@Component
public class StarterInventoryContent {

    public static final String LUMEN_SHARD_ID = "lumen-shard";
    public static final String ECHO_THREAD_ID = "echo-thread";

    private final Map<String, InventoryItemDefinition> items = Map.of(
            LUMEN_SHARD_ID,
            new InventoryItemDefinition(
                    LUMEN_SHARD_ID,
                    "Люминовый осколок",
                    "Стабильный фрагмент светового ядра, пригодный для будущих улучшений."
            ),
            ECHO_THREAD_ID,
            new InventoryItemDefinition(
                    ECHO_THREAD_ID,
                    "Нить эха",
                    "Тонкая энергетическая нить, сохранившая маршрут через хранилище."
            )
    );

    public InventoryItemDefinition require(String itemId) {
        InventoryItemDefinition item = items.get(itemId);
        if (item == null) {
            throw new IllegalArgumentException("Неизвестный inventory item: " + itemId);
        }
        return item;
    }

    public InventoryItemDefinition findOrFallback(String itemId) {
        InventoryItemDefinition item = items.get(itemId);
        return item == null
                ? new InventoryItemDefinition(
                        itemId,
                        itemId,
                        "Предмет из более новой версии контента."
                )
                : item;
    }

    public List<InventoryItemDefinition> items() {
        return items.values().stream()
                .sorted((left, right) -> left.itemId().compareTo(right.itemId()))
                .toList();
    }
}
