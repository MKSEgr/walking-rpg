package com.walkingrpg.backend.expedition.application;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import com.walkingrpg.backend.equipment.application.StarterEquipmentContent;
import com.walkingrpg.backend.expedition.domain.ExpeditionChoiceEquipmentRequirement;
import com.walkingrpg.backend.expedition.domain.ExpeditionDefinition;
import com.walkingrpg.backend.expedition.domain.ExpeditionEventChoiceDefinition;
import com.walkingrpg.backend.expedition.domain.ExpeditionEventDefinition;
import com.walkingrpg.backend.inventory.application.StarterInventoryContent;
import com.walkingrpg.backend.inventory.domain.InventoryRewardDefinition;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

@Component
public class StarterExpeditionContent {

    public static final String LEGACY_CONTENT_VERSION = "chapter-1-v1";
    public static final String CONTENT_VERSION = "chapter-1-v2";
    public static final String STORM_RIFT_CONTENT_VERSION = "chapter-1-v3";
    public static final String VOID_ORCHARD_CONTENT_VERSION = "chapter-1-v4";
    public static final String PRISM_SEXTANT_CONTENT_VERSION = "chapter-1-v5";
    public static final String EXPEDITION_ID = "starter-expedition-v1";
    public static final int LEGACY_NODE_COUNT = 18;
    public static final int NODE_COUNT = 19;
    public static final int STORM_RIFT_NODE_COUNT = 20;
    public static final int VOID_ORCHARD_NODE_COUNT = 22;
    public static final int PRISM_SEXTANT_NODE_COUNT = 23;

    public static final String FIRST_NODE_ID = "outer-beacon";
    public static final String FIRST_EVENT_ID = "signal-source-v1";
    /** Backward-compatible alias used by the first playable tests and clients. */
    public static final String EVENT_ID = FIRST_EVENT_ID;

    public static final String SECOND_NODE_ID = "lumen-gate";
    public static final String SECOND_EVENT_ID = "echo-vault-v1";
    public static final String THIRD_NODE_ID = "ash-orbit";
    public static final String MIRROR_DELTA_NODE_ID = "mirror-delta";
    public static final String MIRROR_DELTA_EVENT_ID = "mirror-delta-v1";
    public static final String RESONANCE_ROUTE_CHOICE_ID = "follow-resonance";
    public static final String RESONANCE_ROUTE_NODE_ID = "resonance-pocket";
    public static final String RESONANCE_ROUTE_EVENT_ID = "resonance-pocket-v1";
    public static final String STORM_ARCHIVE_NODE_ID = "storm-archive";
    public static final String STORM_ARCHIVE_EVENT_ID = "storm-archive-v1";
    public static final String STORM_RIFT_CHOICE_ID = "enter-storm-rift";
    public static final String STORM_RIFT_NODE_ID = "storm-scriptorium";
    public static final String STORM_RIFT_EVENT_ID = "storm-scriptorium-v1";
    public static final String VOID_ORCHARD_NODE_ID = "void-orchard";
    public static final String VOID_ORCHARD_EVENT_ID = "void-orchard-v1";
    public static final String ROOT_ECHO_CHOICE_ID = "descend-root-echo";
    public static final String ROOT_MEMORY_NODE_ID = "root-memory";
    public static final String ROOT_MEMORY_EVENT_ID = "root-memory-v1";
    public static final String LIGHT_CANOPY_CHOICE_ID = "climb-light-canopy";
    public static final String LIGHT_CANOPY_NODE_ID = "light-canopy";
    public static final String LIGHT_CANOPY_EVENT_ID = "light-canopy-v1";
    public static final String EMBER_STATION_NODE_ID = "ember-station";
    public static final String STAR_WELL_NODE_ID = "star-well";
    public static final String STAR_WELL_EVENT_ID = "star-well-v1";
    public static final String PRISM_SEXTANT_ROUTE_CHOICE_ID =
            "align-prism-sextant";
    public static final String SPECTRUM_OBSERVATORY_NODE_ID =
            "spectrum-observatory";
    public static final String SPECTRUM_OBSERVATORY_EVENT_ID =
            "spectrum-observatory-v1";
    public static final String HORIZON_SPIRE_NODE_ID = "horizon-spire";
    public static final String FINAL_NODE_ID = "dawn-relay";

    private static final String EXPEDITION_NAME = "Сигнал из туманного сектора";

    private final List<ExpeditionDefinition> nodes;
    private final Map<String, ExpeditionDefinition> nodeById;
    private final Map<String, ExpeditionDefinition> nodeByEventId;
    private final Map<String, List<ExpeditionEventChoiceDefinition>> choicesByEventId;
    private final Map<String, ExpeditionDefinition> defaultNextNodeByEventId;
    private final Map<EventChoiceKey, ExpeditionDefinition> choiceNextNode;

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
                        "За воротами найден архив маршрутов. Его ядро нестабильно, а питомец слышит зов из глубины."),
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
                new NodeSpec(MIRROR_DELTA_NODE_ID, "Зеркальная дельта", 95,
                        MIRROR_DELTA_EVENT_ID,
                        "Раздвоенный сигнал", "Два одинаковых сигнала ведут к разным берегам."),
                new NodeSpec(STORM_ARCHIVE_NODE_ID, "Грозовой архив", 100,
                        STORM_ARCHIVE_EVENT_ID,
                        "Память грозы", "Архив сохраняет маршруты внутри коротких разрядов."),
                new NodeSpec(EMBER_STATION_NODE_ID, "Угольная станция", 105,
                        "ember-station-v1",
                        "Последний жар", "Станция почти остыла, но её ядро ещё можно запустить."),
                new NodeSpec("aurora-bridge", "Мост сияния", 110, "aurora-bridge-v1",
                        "Полоса света", "Мост строится из лучей, когда шаги совпадают с ритмом маяков."),
                new NodeSpec(VOID_ORCHARD_NODE_ID, "Сад пустоты", 115,
                        VOID_ORCHARD_EVENT_ID,
                        "Невидимый плод", "Сад проявляется только по следу питомца."),
                new NodeSpec(STAR_WELL_NODE_ID, "Звёздный колодец", 120, STAR_WELL_EVENT_ID,
                        "Глубина света", "Колодец возвращает эхо каждого пройденного сектора."),
                new NodeSpec(HORIZON_SPIRE_NODE_ID, "Шпиль горизонта", 125, "horizon-spire-v1",
                        "Высота маршрута", "С вершины виден последний ретранслятор главы."),
                new NodeSpec(FINAL_NODE_ID, "Ретранслятор рассвета", 130, "dawn-relay-v1",
                        "Первый рассвет", "Ретранслятор готов открыть путь к следующей главе.")
        );

        List<ExpeditionDefinition> definitions = new ArrayList<>();
        Map<String, ExpeditionDefinition> byId = new LinkedHashMap<>();
        Map<String, ExpeditionDefinition> byEvent = new LinkedHashMap<>();
        Map<String, List<ExpeditionEventChoiceDefinition>> choices = new LinkedHashMap<>();
        Map<String, ExpeditionDefinition> defaultNext = new LinkedHashMap<>();
        Map<EventChoiceKey, ExpeditionDefinition> choiceNext = new LinkedHashMap<>();

        for (int index = 0; index < specs.size(); index++) {
            NodeSpec spec = specs.get(index);
            ExpeditionDefinition definition = new ExpeditionDefinition(
                    PRISM_SEXTANT_CONTENT_VERSION,
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

        for (int index = 0; index + 1 < specs.size(); index++) {
            defaultNext.put(
                    specs.get(index).eventId(),
                    byId.get(specs.get(index + 1).nodeId())
            );
        }

        NodeSpec resonanceSpec = new NodeSpec(
                RESONANCE_ROUTE_NODE_ID,
                "Резонансный карман",
                35,
                RESONANCE_ROUTE_EVENT_ID,
                "Карта скрытого течения",
                "Компас удерживает проход в карман пространства, где сходятся забытые маршруты."
        );
        ExpeditionDefinition resonanceDefinition = definition(resonanceSpec);
        definitions.add(resonanceDefinition);
        byId.put(resonanceDefinition.currentNodeId(), resonanceDefinition);
        byEvent.put(resonanceDefinition.event().eventId(), resonanceDefinition);
        choices.put(
                RESONANCE_ROUTE_EVENT_ID,
                resonanceRouteChoices(inventoryContent)
        );

        ExpeditionDefinition stormArchive = byId.get(STORM_ARCHIVE_NODE_ID);
        defaultNext.put(RESONANCE_ROUTE_EVENT_ID, stormArchive);
        choiceNext.put(
                new EventChoiceKey(
                        MIRROR_DELTA_EVENT_ID,
                        RESONANCE_ROUTE_CHOICE_ID
                ),
                resonanceDefinition
        );
        List<ExpeditionEventChoiceDefinition> mirrorChoices = new ArrayList<>(
                choices.get(MIRROR_DELTA_EVENT_ID)
        );
        mirrorChoices.add(resonanceRouteChoice(inventoryContent));
        choices.put(MIRROR_DELTA_EVENT_ID, List.copyOf(mirrorChoices));

        NodeSpec stormRiftSpec = new NodeSpec(
                STORM_RIFT_NODE_ID,
                "Грозовой скрипторий",
                40,
                STORM_RIFT_EVENT_ID,
                "Живая запись грозы",
                "Внутри разлома молнии складываются в строки, которые меняют маршрут при каждом раскате."
        );
        ExpeditionDefinition stormRiftDefinition = definition(stormRiftSpec);
        definitions.add(stormRiftDefinition);
        byId.put(stormRiftDefinition.currentNodeId(), stormRiftDefinition);
        byEvent.put(stormRiftDefinition.event().eventId(), stormRiftDefinition);
        choices.put(STORM_RIFT_EVENT_ID, stormRiftChoices(inventoryContent));

        ExpeditionDefinition emberStation = byId.get(EMBER_STATION_NODE_ID);
        defaultNext.put(STORM_RIFT_EVENT_ID, emberStation);
        choiceNext.put(
                new EventChoiceKey(STORM_ARCHIVE_EVENT_ID, STORM_RIFT_CHOICE_ID),
                stormRiftDefinition
        );
        List<ExpeditionEventChoiceDefinition> stormArchiveChoices = new ArrayList<>(
                choices.get(STORM_ARCHIVE_EVENT_ID)
        );
        stormArchiveChoices.add(stormRiftChoice(inventoryContent));
        choices.put(STORM_ARCHIVE_EVENT_ID, List.copyOf(stormArchiveChoices));

        NodeSpec rootMemorySpec = new NodeSpec(
                ROOT_MEMORY_NODE_ID,
                "Память корней",
                45,
                ROOT_MEMORY_EVENT_ID,
                "Архив под садом",
                "Корни удерживают голоса прежних путников и меняют проход в ответ на шаги."
        );
        ExpeditionDefinition rootMemoryDefinition = definition(rootMemorySpec);
        definitions.add(rootMemoryDefinition);
        byId.put(rootMemoryDefinition.currentNodeId(), rootMemoryDefinition);
        byEvent.put(rootMemoryDefinition.event().eventId(), rootMemoryDefinition);
        choices.put(ROOT_MEMORY_EVENT_ID, rootMemoryChoices(inventoryContent));

        NodeSpec lightCanopySpec = new NodeSpec(
                LIGHT_CANOPY_NODE_ID,
                "Световая крона",
                45,
                LIGHT_CANOPY_EVENT_ID,
                "Плод возможного пути",
                "Над садом созрел световой плод, внутри которого мерцает ещё не пройденный маршрут."
        );
        ExpeditionDefinition lightCanopyDefinition = definition(lightCanopySpec);
        definitions.add(lightCanopyDefinition);
        byId.put(lightCanopyDefinition.currentNodeId(), lightCanopyDefinition);
        byEvent.put(lightCanopyDefinition.event().eventId(), lightCanopyDefinition);
        choices.put(LIGHT_CANOPY_EVENT_ID, lightCanopyChoices(inventoryContent));

        ExpeditionDefinition starWell = byId.get(STAR_WELL_NODE_ID);
        defaultNext.put(ROOT_MEMORY_EVENT_ID, starWell);
        defaultNext.put(LIGHT_CANOPY_EVENT_ID, starWell);
        choiceNext.put(
                new EventChoiceKey(VOID_ORCHARD_EVENT_ID, ROOT_ECHO_CHOICE_ID),
                rootMemoryDefinition
        );
        choiceNext.put(
                new EventChoiceKey(VOID_ORCHARD_EVENT_ID, LIGHT_CANOPY_CHOICE_ID),
                lightCanopyDefinition
        );
        List<ExpeditionEventChoiceDefinition> voidOrchardChoices = new ArrayList<>(
                choices.get(VOID_ORCHARD_EVENT_ID)
        );
        voidOrchardChoices.add(rootEchoChoice(inventoryContent));
        voidOrchardChoices.add(lightCanopyChoice(inventoryContent));
        choices.put(VOID_ORCHARD_EVENT_ID, List.copyOf(voidOrchardChoices));

        NodeSpec spectrumObservatorySpec = new NodeSpec(
                SPECTRUM_OBSERVATORY_NODE_ID,
                "Спектральная обсерватория",
                50,
                SPECTRUM_OBSERVATORY_EVENT_ID,
                "Карта невидимого света",
                "Секстант разложил сияние колодца на пути, которые нельзя увидеть напрямую."
        );
        ExpeditionDefinition spectrumObservatoryDefinition = definition(
                spectrumObservatorySpec
        );
        definitions.add(spectrumObservatoryDefinition);
        byId.put(
                spectrumObservatoryDefinition.currentNodeId(),
                spectrumObservatoryDefinition
        );
        byEvent.put(
                spectrumObservatoryDefinition.event().eventId(),
                spectrumObservatoryDefinition
        );
        choices.put(
                SPECTRUM_OBSERVATORY_EVENT_ID,
                spectrumObservatoryChoices(inventoryContent)
        );

        ExpeditionDefinition horizonSpire = byId.get(HORIZON_SPIRE_NODE_ID);
        defaultNext.put(SPECTRUM_OBSERVATORY_EVENT_ID, horizonSpire);
        choiceNext.put(
                new EventChoiceKey(
                        STAR_WELL_EVENT_ID,
                        PRISM_SEXTANT_ROUTE_CHOICE_ID
                ),
                spectrumObservatoryDefinition
        );
        List<ExpeditionEventChoiceDefinition> starWellChoices = new ArrayList<>(
                choices.get(STAR_WELL_EVENT_ID)
        );
        starWellChoices.add(prismSextantRouteChoice(inventoryContent));
        choices.put(STAR_WELL_EVENT_ID, List.copyOf(starWellChoices));

        this.nodes = List.copyOf(definitions);
        this.nodeById = Map.copyOf(byId);
        this.nodeByEventId = Map.copyOf(byEvent);
        this.choicesByEventId = Map.copyOf(choices);
        this.defaultNextNodeByEventId = Map.copyOf(defaultNext);
        this.choiceNextNode = Map.copyOf(choiceNext);
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
        requireEvent(eventId);
        return Optional.ofNullable(defaultNextNodeByEventId.get(eventId));
    }

    public Optional<ExpeditionDefinition> nextNodeAfterEvent(
            String eventId,
            String choiceId
    ) {
        return nextNodeAfterEvent(
                eventId,
                choiceId,
                PRISM_SEXTANT_CONTENT_VERSION
        );
    }

    public Optional<ExpeditionDefinition> nextNodeAfterEvent(
            String eventId,
            String choiceId,
            boolean resonanceRouteActive
    ) {
        return nextNodeAfterEvent(
                eventId,
                choiceId,
                resonanceRouteActive ? CONTENT_VERSION : LEGACY_CONTENT_VERSION
        );
    }

    public Optional<ExpeditionDefinition> nextNodeAfterEvent(
            String eventId,
            String choiceId,
            String activeContentVersion
    ) {
        requireChoice(eventId, choiceId, activeContentVersion);
        ExpeditionDefinition explicit = choiceNextNode.get(
                new EventChoiceKey(eventId, choiceId)
        );
        return explicit == null
                ? nextNodeAfterEvent(eventId)
                : Optional.of(explicit);
    }

    public ExpeditionEventChoiceDefinition requireChoice(
            String eventId,
            String choiceId
    ) {
        return requireChoice(eventId, choiceId, PRISM_SEXTANT_CONTENT_VERSION);
    }

    public ExpeditionEventChoiceDefinition requireChoice(
            String eventId,
            String choiceId,
            boolean resonanceRouteActive
    ) {
        return requireChoice(
                eventId,
                choiceId,
                resonanceRouteActive ? CONTENT_VERSION : LEGACY_CONTENT_VERSION
        );
    }

    public ExpeditionEventChoiceDefinition requireChoice(
            String eventId,
            String choiceId,
            String activeContentVersion
    ) {
        return eventChoices(eventId, activeContentVersion).stream()
                .filter(choice -> choice.choiceId().equals(choiceId))
                .findFirst()
                .orElseThrow(() -> new EventResolutionValidationException(
                        "Неизвестный choiceId для события " + eventId,
                        "choiceId"
                ));
    }

    public List<ExpeditionEventChoiceDefinition> eventChoices(String eventId) {
        return eventChoices(eventId, PRISM_SEXTANT_CONTENT_VERSION);
    }

    public List<ExpeditionEventChoiceDefinition> eventChoices(
            String eventId,
            boolean resonanceRouteActive
    ) {
        return eventChoices(
                eventId,
                resonanceRouteActive ? CONTENT_VERSION : LEGACY_CONTENT_VERSION
        );
    }

    public List<ExpeditionEventChoiceDefinition> eventChoices(
            String eventId,
            String activeContentVersion
    ) {
        requireEvent(eventId);
        List<ExpeditionEventChoiceDefinition> choices = choicesByEventId.get(eventId);
        if (MIRROR_DELTA_EVENT_ID.equals(eventId)
                && !supportsResonanceRoute(activeContentVersion)) {
            return choices.stream()
                    .filter(choice -> !RESONANCE_ROUTE_CHOICE_ID.equals(
                            choice.choiceId()
                    ))
                    .toList();
        }
        if (STORM_ARCHIVE_EVENT_ID.equals(eventId)
                && !supportsStormRift(activeContentVersion)) {
            return choices.stream()
                    .filter(choice -> !STORM_RIFT_CHOICE_ID.equals(
                            choice.choiceId()
                    ))
                    .toList();
        }
        if (VOID_ORCHARD_EVENT_ID.equals(eventId)
                && !supportsVoidOrchardFork(activeContentVersion)) {
            return choices.stream()
                    .filter(choice -> !ROOT_ECHO_CHOICE_ID.equals(choice.choiceId()))
                    .filter(choice -> !LIGHT_CANOPY_CHOICE_ID.equals(choice.choiceId()))
                    .toList();
        }
        if (STAR_WELL_EVENT_ID.equals(eventId)
                && !supportsPrismSextantRoute(activeContentVersion)) {
            return choices.stream()
                    .filter(choice -> !PRISM_SEXTANT_ROUTE_CHOICE_ID.equals(
                            choice.choiceId()
                    ))
                    .toList();
        }
        return choices;
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
        return PRISM_SEXTANT_CONTENT_VERSION;
    }

    public String contentVersion(boolean resonanceRouteActive) {
        return resonanceRouteActive ? CONTENT_VERSION : LEGACY_CONTENT_VERSION;
    }

    public String activeContentVersion(ExpeditionContentActivation activation) {
        String activeContentVersion = activation.activeContentVersion();
        if (PRISM_SEXTANT_CONTENT_VERSION.equals(activeContentVersion)) {
            return PRISM_SEXTANT_CONTENT_VERSION;
        }
        if (VOID_ORCHARD_CONTENT_VERSION.equals(activeContentVersion)) {
            return VOID_ORCHARD_CONTENT_VERSION;
        }
        if (STORM_RIFT_CONTENT_VERSION.equals(activeContentVersion)) {
            return STORM_RIFT_CONTENT_VERSION;
        }
        if (CONTENT_VERSION.equals(activeContentVersion)) {
            return CONTENT_VERSION;
        }
        return LEGACY_CONTENT_VERSION;
    }

    public static boolean supportsResonanceRoute(String contentVersion) {
        return CONTENT_VERSION.equals(contentVersion)
                || STORM_RIFT_CONTENT_VERSION.equals(contentVersion)
                || VOID_ORCHARD_CONTENT_VERSION.equals(contentVersion)
                || PRISM_SEXTANT_CONTENT_VERSION.equals(contentVersion);
    }

    public static boolean supportsStormRift(String contentVersion) {
        return STORM_RIFT_CONTENT_VERSION.equals(contentVersion)
                || VOID_ORCHARD_CONTENT_VERSION.equals(contentVersion)
                || PRISM_SEXTANT_CONTENT_VERSION.equals(contentVersion);
    }

    public static boolean supportsVoidOrchardFork(String contentVersion) {
        return VOID_ORCHARD_CONTENT_VERSION.equals(contentVersion)
                || PRISM_SEXTANT_CONTENT_VERSION.equals(contentVersion);
    }

    public static boolean supportsPrismSextantRoute(String contentVersion) {
        return PRISM_SEXTANT_CONTENT_VERSION.equals(contentVersion);
    }

    private ExpeditionDefinition definition(NodeSpec spec) {
        return new ExpeditionDefinition(
                PRISM_SEXTANT_CONTENT_VERSION,
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
    }

    private ExpeditionEventChoiceDefinition resonanceRouteChoice(
            StarterInventoryContent inventoryContent
    ) {
        return new ExpeditionEventChoiceDefinition(
                RESONANCE_ROUTE_CHOICE_ID,
                "Пойти по резонансу",
                "Настроить экипированный компас на скрытое отражение дельты.",
                "Скрытый маршрут",
                "Компас отделил настоящий импульс от отражений и открыл проход в резонансный карман.",
                35,
                16,
                reward(
                        inventoryContent,
                        StarterInventoryContent.DAWN_FRAGMENT_ID,
                        1
                ),
                new ExpeditionChoiceEquipmentRequirement(
                        StarterEquipmentContent.NAVIGATION_SLOT_ID,
                        "Навигационный прибор",
                        inventoryContent.require(
                                StarterInventoryContent.RESONANCE_COMPASS_ID
                        ),
                        "Экипируйте резонансный компас, чтобы увидеть скрытый маршрут."
                )
        );
    }

    private List<ExpeditionEventChoiceDefinition> resonanceRouteChoices(
            StarterInventoryContent inventoryContent
    ) {
        return List.of(
                new ExpeditionEventChoiceDefinition(
                        "map-hidden-current",
                        "Нанести течение на карту",
                        "Зафиксировать устойчивые точки кармана для следующих экспедиций.",
                        "Карта резонанса",
                        "Навигатор сохранил скрытую геометрию и собрал призматическую пыль с границ прохода.",
                        38,
                        12,
                        reward(
                                inventoryContent,
                                StarterInventoryContent.PRISM_DUST_ID,
                                2
                        )
                ),
                new ExpeditionEventChoiceDefinition(
                        "follow-compass-pulse",
                        "Следовать за импульсом",
                        "Доверить компас питомцу и пройти к самому яркому отклику.",
                        "Осколок будущего",
                        "Питомец удержал проход, пока компас извлёк фрагмент света из ещё не открытого рассвета.",
                        28,
                        20,
                        reward(
                                inventoryContent,
                                StarterInventoryContent.DAWN_FRAGMENT_ID,
                                1
                        )
                )
        );
    }

    private ExpeditionEventChoiceDefinition stormRiftChoice(
            StarterInventoryContent inventoryContent
    ) {
        return new ExpeditionEventChoiceDefinition(
                STORM_RIFT_CHOICE_ID,
                "Войти в грозовой разлом",
                "Удержать разлом экипированным компасом и пройти внутрь архива.",
                "Путь сквозь молнию",
                "Компас синхронизировал разряды и открыл дорогу в грозовой скрипторий.",
                42,
                18,
                reward(
                        inventoryContent,
                        StarterInventoryContent.ION_BLOOM_ID,
                        1
                ),
                new ExpeditionChoiceEquipmentRequirement(
                        StarterEquipmentContent.NAVIGATION_SLOT_ID,
                        "Навигационный прибор",
                        inventoryContent.require(
                                StarterInventoryContent.RESONANCE_COMPASS_ID
                        ),
                        "Экипируйте резонансный компас, чтобы стабилизировать грозовой разлом."
                )
        );
    }

    private List<ExpeditionEventChoiceDefinition> stormRiftChoices(
            StarterInventoryContent inventoryContent
    ) {
        return List.of(
                new ExpeditionEventChoiceDefinition(
                        "decode-lightning-script",
                        "Расшифровать письмена",
                        "Сопоставить вспышки с картой архива и сохранить устойчивую последовательность.",
                        "Грозовой шифр",
                        "Навигатор прочитал живую запись и собрал нити эха между строками молний.",
                        45,
                        14,
                        reward(
                                inventoryContent,
                                StarterInventoryContent.ECHO_THREAD_ID,
                                2
                        )
                ),
                new ExpeditionEventChoiceDefinition(
                        "chase-rolling-thunder",
                        "Догнать раскат",
                        "Позволить питомцу вести отряд за самым глубоким эхом разлома.",
                        "Сердце грозы",
                        "Питомец настиг раскат и вынес из него фрагмент рассветного света.",
                        30,
                        24,
                        reward(
                                inventoryContent,
                                StarterInventoryContent.DAWN_FRAGMENT_ID,
                                1
                        )
                )
        );
    }

    private ExpeditionEventChoiceDefinition rootEchoChoice(
            StarterInventoryContent inventoryContent
    ) {
        return new ExpeditionEventChoiceDefinition(
                ROOT_ECHO_CHOICE_ID,
                "Спуститься за корневым эхом",
                "Позволить питомцу найти голос, который звучит из-под сада.",
                "Тропа под корнями",
                "Питомец отделил живой голос от старых отражений и открыл проход в память корней.",
                36,
                22,
                reward(
                        inventoryContent,
                        StarterInventoryContent.ECHO_THREAD_ID,
                        1
                )
        );
    }

    private ExpeditionEventChoiceDefinition lightCanopyChoice(
            StarterInventoryContent inventoryContent
    ) {
        return new ExpeditionEventChoiceDefinition(
                LIGHT_CANOPY_CHOICE_ID,
                "Подняться к световой кроне",
                "Проложить путь по проявляющимся ветвям к самому яркому плоду.",
                "Дорога над садом",
                "Навигатор связал вспышки в устойчивую лестницу и вывел отряд к световой кроне.",
                44,
                18,
                reward(
                        inventoryContent,
                        StarterInventoryContent.ION_BLOOM_ID,
                        1
                )
        );
    }

    private List<ExpeditionEventChoiceDefinition> rootMemoryChoices(
            StarterInventoryContent inventoryContent
    ) {
        return List.of(
                new ExpeditionEventChoiceDefinition(
                        "map-root-memory",
                        "Составить карту голосов",
                        "Отделить повторяющиеся воспоминания и отметить безопасный путь наружу.",
                        "Карта подземного хора",
                        "Навигатор сохранил голоса в нитях эха и нашёл выход к звёздному колодцу.",
                        46,
                        15,
                        reward(
                                inventoryContent,
                                StarterInventoryContent.ECHO_THREAD_ID,
                                2
                        )
                ),
                new ExpeditionEventChoiceDefinition(
                        "wake-buried-seed",
                        "Разбудить погребённое семя",
                        "Доверить питомцу самый тихий голос под корнями.",
                        "Семя памяти",
                        "Питомец пробудил древнее семя и вывел его к свету, не разрушив архив.",
                        32,
                        24,
                        reward(
                                inventoryContent,
                                StarterInventoryContent.ASH_SEED_ID,
                                2
                        )
                )
        );
    }

    private List<ExpeditionEventChoiceDefinition> lightCanopyChoices(
            StarterInventoryContent inventoryContent
    ) {
        return List.of(
                new ExpeditionEventChoiceDefinition(
                        "calibrate-light-fruit",
                        "Настроить световой плод",
                        "Стабилизировать мерцающий маршрут и извлечь сохранённый свет.",
                        "Устойчивое сияние",
                        "Навигатор закрепил один возможный путь и собрал люминовые осколки с его границы.",
                        48,
                        14,
                        reward(
                                inventoryContent,
                                StarterInventoryContent.LUMEN_SHARD_ID,
                                2
                        )
                ),
                new ExpeditionEventChoiceDefinition(
                        "leap-between-rays",
                        "Прыгнуть между лучами",
                        "Позволить питомцу догнать путь, который появляется только на миг.",
                        "Свет будущего",
                        "Питомец настиг исчезающий маршрут и принёс фрагмент света к звёздному колодцу.",
                        31,
                        25,
                        reward(
                                inventoryContent,
                                StarterInventoryContent.DAWN_FRAGMENT_ID,
                                1
                        )
                )
        );
    }

    private ExpeditionEventChoiceDefinition prismSextantRouteChoice(
            StarterInventoryContent inventoryContent
    ) {
        return new ExpeditionEventChoiceDefinition(
                PRISM_SEXTANT_ROUTE_CHOICE_ID,
                "Свести скрытый спектр",
                "Настроить экипированный секстант на свет под поверхностью колодца.",
                "Путь невидимого света",
                "Секстант разделил отражения и открыл подъём в спектральную обсерваторию.",
                50,
                20,
                reward(
                        inventoryContent,
                        StarterInventoryContent.PRISM_DUST_ID,
                        1
                ),
                new ExpeditionChoiceEquipmentRequirement(
                        StarterEquipmentContent.NAVIGATION_SLOT_ID,
                        "Навигационный прибор",
                        inventoryContent.require(
                                StarterInventoryContent.PRISM_SEXTANT_ID
                        ),
                        "Экипируйте призматический секстант, чтобы увидеть скрытый спектр."
                )
        );
    }

    private List<ExpeditionEventChoiceDefinition> spectrumObservatoryChoices(
            StarterInventoryContent inventoryContent
    ) {
        return List.of(
                new ExpeditionEventChoiceDefinition(
                        "chart-invisible-constellation",
                        "Нанести созвездие на карту",
                        "Зафиксировать устойчивые линии спектра для следующих маршрутов.",
                        "Атлас невидимого света",
                        "Навигатор сохранил карту и собрал ионный заряд с её опорных точек.",
                        52,
                        16,
                        reward(
                                inventoryContent,
                                StarterInventoryContent.ION_BLOOM_ID,
                                2
                        )
                ),
                new ExpeditionEventChoiceDefinition(
                        "chase-dawn-refraction",
                        "Догнать преломление рассвета",
                        "Доверить питомцу луч, который появляется между цветами спектра.",
                        "Свет за пределом спектра",
                        "Питомец удержал исчезающий луч и вынес два фрагмента рассвета.",
                        34,
                        28,
                        reward(
                                inventoryContent,
                                StarterInventoryContent.DAWN_FRAGMENT_ID,
                                2
                        )
                )
        );
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
                            "Довериться питомцу",
                            "Позволить питомцу найти путь по колебаниям света.",
                            "След Люмина",
                            "Питомец распознал живой отклик маяка и вывел отряд к скрытому входу.",
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
                            "Питомец проведёт отряд по живому следу в глубине архива.",
                            "Нить маршрута",
                            "Питомец нашёл безопасный путь и вынес нить эха, сохранившую его структуру.",
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

    private record EventChoiceKey(String eventId, String choiceId) {
    }
}
