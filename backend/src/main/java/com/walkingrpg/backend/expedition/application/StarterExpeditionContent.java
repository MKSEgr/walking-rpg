package com.walkingrpg.backend.expedition.application;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import com.walkingrpg.backend.expedition.domain.ExpeditionDefinition;
import com.walkingrpg.backend.expedition.domain.ExpeditionEventChoiceDefinition;
import com.walkingrpg.backend.expedition.domain.ExpeditionEventDefinition;
import com.walkingrpg.backend.inventory.application.StarterInventoryContent;
import com.walkingrpg.backend.inventory.domain.InventoryRewardDefinition;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

@Component
public class StarterExpeditionContent {

    public static final String CONTENT_VERSION = "chapter-1-v1";
    public static final String EXPEDITION_ID = "starter-expedition-v1";

    public static final String FIRST_NODE_ID = "outer-beacon";
    public static final String FIRST_EVENT_ID = "signal-source-v1";
    /** Backward-compatible alias used by the first playable tests and clients. */
    public static final String EVENT_ID = FIRST_EVENT_ID;

    public static final String SECOND_NODE_ID = "lumen-gate";
    public static final String SECOND_EVENT_ID = "echo-vault-v1";
    public static final String THIRD_NODE_ID = "ash-orbit";
    public static final String FINAL_NODE_ID = "dawn-relay";

    private static final String EXPEDITION_NAME = "Сигнал из туманного сектора";

    private final List<ExpeditionDefinition> nodes;
    private final Map<String, ExpeditionDefinition> nodeById;
    private final Map<String, ExpeditionDefinition> nodeByEventId;
    private final Map<String, List<ExpeditionEventChoiceDefinition>> choicesByEventId;

    public StarterExpeditionContent() {
        this(new StarterInventoryContent());
    }

    @Autowired
    public StarterExpeditionContent(StarterInventoryContent inventoryContent) {
        List<NodeSpec> specs = List.of(
                new NodeSpec(FIRST_NODE_ID, "Внешний маяк", 30, FIRST_EVENT_ID,
                        "Источник сигнала",
                        "Маяк отвечает повторяющимся импульсом. Нужно решить, как войти внутрь."),
                new NodeSpec(SECOND_NODE_ID, "Люминовые ворота", 45, SECOND_EVENT_ID,
                        "Хранилище эха",
                        "За воротами найден архив маршрутов. Его ядро нестабильно, а Искра слышит зов из глубины."),
                new NodeSpec(THIRD_NODE_ID, "Пепельная орбита", 55, "ash-orbit-v1",
                        "Пепельный след", "Вокруг станции вращается тёплый пепел с живыми искрами."),
                new NodeSpec("glass-marsh", "Стеклянные топи", 60, "glass-marsh-v1",
                        "Зеркальная тропа", "Тонкие пластины отражают несколько возможных маршрутов."),
                new NodeSpec("silent-quarry", "Тихий карьер", 65, "silent-quarry-v1",
                        "Спящий экскаватор", "В глубине карьера сохранился автоматический добывающий модуль."),
                new NodeSpec("copper-ravine", "Медный разлом", 70, "copper-ravine-v1",
                        "Медное сердце", "Разлом отвечает на шаги низким металлическим тоном."),
                new NodeSpec("ion-garden", "Ионный сад", 75, "ion-garden-v1",
                        "Цветение заряда", "Растения накапливают импульсы и открываются только в движении."),
                new NodeSpec("frost-antenna", "Ледяная антенна", 80, "frost-antenna-v1",
                        "Замёрзшая передача", "Антенна хранит пакет данных под слоем кристаллического льда."),
                new NodeSpec("obsidian-crossing", "Обсидиановая переправа", 85,
                        "obsidian-crossing-v1", "Тёмный мост",
                        "Переправа реагирует на свет питомца и вес экипировки."),
                new NodeSpec("pulse-foundry", "Импульсная литейная", 90, "pulse-foundry-v1",
                        "Пульс формы", "Старые формы могут создать ключ к следующему сектору."),
                new NodeSpec("mirror-delta", "Зеркальная дельта", 95, "mirror-delta-v1",
                        "Раздвоенный сигнал", "Два одинаковых сигнала ведут к разным берегам."),
                new NodeSpec("storm-archive", "Грозовой архив", 100, "storm-archive-v1",
                        "Память грозы", "Архив сохраняет маршруты внутри коротких разрядов."),
                new NodeSpec("ember-station", "Угольная станция", 105, "ember-station-v1",
                        "Последний жар", "Станция почти остыла, но её ядро ещё можно запустить."),
                new NodeSpec("aurora-bridge", "Мост сияния", 110, "aurora-bridge-v1",
                        "Полоса света", "Мост строится из лучей, когда шаги совпадают с ритмом маяков."),
                new NodeSpec("void-orchard", "Сад пустоты", 115, "void-orchard-v1",
                        "Невидимый плод", "Сад проявляется только по следу питомца."),
                new NodeSpec("star-well", "Звёздный колодец", 120, "star-well-v1",
                        "Глубина света", "Колодец возвращает эхо каждого пройденного сектора."),
                new NodeSpec("horizon-spire", "Шпиль горизонта", 125, "horizon-spire-v1",
                        "Высота маршрута", "С вершины виден последний ретранслятор главы."),
                new NodeSpec(FINAL_NODE_ID, "Ретранслятор рассвета", 130, "dawn-relay-v1",
                        "Первый рассвет", "Ретранслятор готов открыть путь к следующей главе.")
        );

        List<ExpeditionDefinition> definitions = new ArrayList<>();
        Map<String, ExpeditionDefinition> byId = new LinkedHashMap<>();
        Map<String, ExpeditionDefinition> byEvent = new LinkedHashMap<>();
        Map<String, List<ExpeditionEventChoiceDefinition>> choices = new LinkedHashMap<>();

        for (int index = 0; index < specs.size(); index++) {
            NodeSpec spec = specs.get(index);
            ExpeditionDefinition definition = new ExpeditionDefinition(
                    CONTENT_VERSION,
                    EXPEDITION_ID,
                    EXPEDITION_NAME,
                    spec.nodeId(),
                    spec.nodeName(),
                    spec.requiredEnergy(),
                    new ExpeditionEventDefinition(
                            spec.eventId(),
                            spec.eventTitle(),
                            spec.eventSummary()
                    )
            );
            definitions.add(definition);
            byId.put(definition.currentNodeId(), definition);
            byEvent.put(definition.event().eventId(), definition);
            choices.put(spec.eventId(), choicesFor(index, spec, inventoryContent));
        }

        this.nodes = List.copyOf(definitions);
        this.nodeById = Map.copyOf(byId);
        this.nodeByEventId = Map.copyOf(byEvent);
        this.choicesByEventId = Map.copyOf(choices);
    }

    public ExpeditionDefinition require(String expeditionId) {
        if (!EXPEDITION_ID.equals(expeditionId)) {
            throw new ExpeditionNotFoundException(expeditionId);
        }
        return initialDefinition();
    }

    public ExpeditionDefinition requireNode(String nodeId) {
        ExpeditionDefinition definition = nodeById.get(nodeId);
        if (definition == null) {
            throw new IllegalStateException(
                    "Неизвестный узел экспедиции в сохранённом состоянии: " + nodeId
            );
        }
        return definition;
    }

    public ExpeditionDefinition requireEvent(String eventId) {
        ExpeditionDefinition definition = nodeByEventId.get(eventId);
        if (definition == null) {
            throw new EventNotFoundException(eventId);
        }
        return definition;
    }

    public Optional<ExpeditionDefinition> nextNodeAfterEvent(String eventId) {
        ExpeditionDefinition current = requireEvent(eventId);
        int index = nodes.indexOf(current);
        return index >= 0 && index + 1 < nodes.size()
                ? Optional.of(nodes.get(index + 1))
                : Optional.empty();
    }

    public ExpeditionEventChoiceDefinition requireChoice(
            String eventId,
            String choiceId
    ) {
        return eventChoices(eventId).stream()
                .filter(choice -> choice.choiceId().equals(choiceId))
                .findFirst()
                .orElseThrow(() -> new EventResolutionValidationException(
                        "Неизвестный choiceId для события " + eventId,
                        "choiceId"
                ));
    }

    public List<ExpeditionEventChoiceDefinition> eventChoices(String eventId) {
        requireEvent(eventId);
        return choicesByEventId.get(eventId);
    }

    public ExpeditionDefinition definition() {
        return initialDefinition();
    }

    public ExpeditionDefinition initialDefinition() {
        return nodes.getFirst();
    }

    public List<ExpeditionDefinition> nodes() {
        return nodes;
    }

    public String contentVersion() {
        return CONTENT_VERSION;
    }

    private List<ExpeditionEventChoiceDefinition> choicesFor(
            int index,
            NodeSpec spec,
            StarterInventoryContent inventoryContent
    ) {
        if (index == 0) {
            return List.of(
                    new ExpeditionEventChoiceDefinition(
                            "analyze-signal",
                            "Проанализировать сигнал",
                            "Пилот вручную сопоставит частоты маяка.",
                            "Карта импульсов",
                            "Навигатор выделил безопасный ритм доступа и сохранил координаты следующего сектора.",
                            40,
                            5
                    ),
                    new ExpeditionEventChoiceDefinition(
                            "trust-spark",
                            "Довериться Искре",
                            "Позволить питомцу найти путь по колебаниям света.",
                            "След Люмина",
                            "Искра распознала живой отклик маяка и вывела отряд к скрытому входу.",
                            20,
                            15
                    )
            );
        }
        if (index == 1) {
            return List.of(
                    new ExpeditionEventChoiceDefinition(
                            "stabilize-core",
                            "Стабилизировать ядро",
                            "Навигатор зафиксирует резонанс и извлечёт безопасные фрагменты.",
                            "Стабильный резонанс",
                            "Ядро перестало разрушаться, а два люминовых осколка сохранили его энергию.",
                            30,
                            8,
                            reward(inventoryContent, StarterInventoryContent.LUMEN_SHARD_ID, 2)
                    ),
                    new ExpeditionEventChoiceDefinition(
                            "follow-echo",
                            "Последовать за эхом",
                            "Искра проведёт отряд по живому следу в глубине архива.",
                            "Нить маршрута",
                            "Искра нашла безопасный путь и вынесла нить эха, сохранившую его структуру.",
                            20,
                            18,
                            reward(inventoryContent, StarterInventoryContent.ECHO_THREAD_ID, 1)
                    )
            );
        }

        String[] materialIds = {
                StarterInventoryContent.ASH_SEED_ID,
                StarterInventoryContent.PRISM_DUST_ID,
                StarterInventoryContent.ION_BLOOM_ID,
                StarterInventoryContent.LUMEN_SHARD_ID,
                StarterInventoryContent.ECHO_THREAD_ID,
                StarterInventoryContent.DAWN_FRAGMENT_ID
        };
        String firstMaterial = materialIds[(index - 2) % materialIds.length];
        String secondMaterial = materialIds[(index - 1) % materialIds.length];
        String suffix = spec.eventId().replace("-v1", "");
        int chapterPosition = index + 1;
        return List.of(
                new ExpeditionEventChoiceDefinition(
                        "survey-" + suffix,
                        "Исследовать узел",
                        "Навигатор проведёт точные измерения и сохранит безопасный маршрут.",
                        "Узел изучен",
                        "Команда получила устойчивую карту сектора и материалы для дальнейшего пути.",
                        20 + chapterPosition,
                        5 + chapterPosition % 5,
                        reward(inventoryContent, firstMaterial, 1 + chapterPosition % 2)
                ),
                new ExpeditionEventChoiceDefinition(
                        "trust-" + suffix,
                        "Следовать за питомцем",
                        "Активный питомец выберет путь по энергетическому следу.",
                        "Живой маршрут",
                        "Питомец нашёл короткую дорогу и принёс редкий материал из глубины узла.",
                        15 + chapterPosition,
                        10 + chapterPosition % 7,
                        reward(inventoryContent, secondMaterial, 1)
                )
        );
    }

    private InventoryRewardDefinition reward(
            StarterInventoryContent content,
            String itemId,
            long quantity
    ) {
        return new InventoryRewardDefinition(content.require(itemId), quantity);
    }

    private record NodeSpec(
            String nodeId,
            String nodeName,
            int requiredEnergy,
            String eventId,
            String eventTitle,
            String eventSummary
    ) {
    }
}
