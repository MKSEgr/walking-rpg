package com.walkingrpg.backend.inventory.application;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import com.walkingrpg.backend.inventory.domain.InventoryItemDefinition;
import com.walkingrpg.backend.inventory.domain.InventoryItemKind;
import org.springframework.stereotype.Component;

@Component
public class StarterInventoryContent {

    public static final String LUMEN_SHARD_ID = "lumen-shard";
    public static final String ECHO_THREAD_ID = "echo-thread";
    public static final String ASH_SEED_ID = "ash-seed";
    public static final String PRISM_DUST_ID = "prism-dust";
    public static final String ION_BLOOM_ID = "ion-bloom";
    public static final String DAWN_FRAGMENT_ID = "dawn-fragment";
    public static final String RESONANCE_COMPASS_ID = "resonance-compass";
    public static final String PRISM_SEXTANT_ID = "prism-sextant";

    private final Map<String, InventoryItemDefinition> items;

    public StarterInventoryContent() {
        Map<String, InventoryItemDefinition> definitions = new LinkedHashMap<>();
        definitions.put(
                LUMEN_SHARD_ID,
                new InventoryItemDefinition(
                        LUMEN_SHARD_ID,
                        "Люминовый осколок",
                        "Стабильный фрагмент светового ядра, пригодный для будущих улучшений."
                )
        );
        definitions.put(
                ECHO_THREAD_ID,
                new InventoryItemDefinition(
                        ECHO_THREAD_ID,
                        "Нить эха",
                        "Тонкая энергетическая нить, сохранившая маршрут через хранилище."
                )
        );
        definitions.put(
                ASH_SEED_ID,
                new InventoryItemDefinition(
                        ASH_SEED_ID,
                        "Семя пепла",
                        "Тёплое зерно из пепельной орбиты, реагирующее на движение пилота."
                )
        );
        definitions.put(
                PRISM_DUST_ID,
                new InventoryItemDefinition(
                        PRISM_DUST_ID,
                        "Призматическая пыль",
                        "Мелкие кристаллы, меняющие спектр рядом с активным питомцем."
                )
        );
        definitions.put(
                ION_BLOOM_ID,
                new InventoryItemDefinition(
                        ION_BLOOM_ID,
                        "Ионный цветок",
                        "Редкий материал, накопивший заряд в садах первой главы."
                )
        );
        definitions.put(
                DAWN_FRAGMENT_ID,
                new InventoryItemDefinition(
                        DAWN_FRAGMENT_ID,
                        "Фрагмент рассвета",
                        "Сезонный материал из последнего ретранслятора первой главы."
                )
        );
        definitions.put(
                RESONANCE_COMPASS_ID,
                new InventoryItemDefinition(
                        RESONANCE_COMPASS_ID,
                        "Резонансный компас",
                        "Уникальный прибор, собранный из люминовых осколков и нити эха.",
                        InventoryItemKind.UNIQUE
                )
        );
        definitions.put(
                PRISM_SEXTANT_ID,
                new InventoryItemDefinition(
                        PRISM_SEXTANT_ID,
                        "Призматический секстант",
                        "Уникальный прибор, сводящий свет поздних маршрутов в карту скрытого спектра.",
                        InventoryItemKind.UNIQUE
                )
        );
        this.items = Map.copyOf(definitions);
    }

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
