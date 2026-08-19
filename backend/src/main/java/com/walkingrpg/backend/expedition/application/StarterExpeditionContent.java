package com.walkingrpg.backend.expedition.application;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import com.walkingrpg.backend.equipment.application.StarterEquipmentContent;
import com.walkingrpg.backend.expedition.domain.ExpeditionChoiceEquipmentRequirement;
import com.walkingrpg.backend.expedition.domain.ExpeditionChoicePetRequirement;
import com.walkingrpg.backend.expedition.domain.ExpeditionChoiceSkillRequirement;
import com.walkingrpg.backend.expedition.domain.ExpeditionDefinition;
import com.walkingrpg.backend.expedition.domain.ExpeditionEventChoiceDefinition;
import com.walkingrpg.backend.expedition.domain.ExpeditionEventDefinition;
import com.walkingrpg.backend.inventory.application.StarterInventoryContent;
import com.walkingrpg.backend.inventory.domain.InventoryRewardDefinition;
import com.walkingrpg.backend.platform.domain.PlatformSkillIds;
import com.walkingrpg.backend.progression.application.StarterProgressionContent;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

@Component
public class StarterExpeditionContent {

    public static final String LEGACY_CONTENT_VERSION = "chapter-1-v1";
    public static final String CONTENT_VERSION = "chapter-1-v2";
    public static final String STORM_RIFT_CONTENT_VERSION = "chapter-1-v3";
    public static final String VOID_ORCHARD_CONTENT_VERSION = "chapter-1-v4";
    public static final String PRISM_SEXTANT_CONTENT_VERSION = "chapter-1-v5";
    public static final String CALIBRATED_SEXTANT_CONTENT_VERSION =
            "chapter-1-v6";
    public static final String SECOND_DAWN_CONTENT_VERSION = "chapter-1-v7";
    public static final String SECOND_DAWN_ATTUNEMENT_CONTENT_VERSION =
            "chapter-1-v8";
    public static final String UNCHARTED_VERGE_CONTENT_VERSION =
            "chapter-1-v9";
    public static final String PET_GUIDED_UNCHARTED_CONTENT_VERSION =
            "chapter-1-v10";
    public static final String ADULT_PET_EVOLUTION_CONTENT_VERSION =
            "chapter-1-v11";
    public static final String ADULT_PET_FRONTIER_CONTENT_VERSION =
            "chapter-1-v12";
    public static final String PILOT_SKILL_CHOICE_CONTENT_VERSION =
            "chapter-1-v13";
    public static final String SIGNAL_READER_SECRET_ROUTE_CONTENT_VERSION =
            "chapter-1-v14";
    public static final String TRAIL_MEMORY_ROUTE_CONTENT_VERSION =
            "chapter-1-v15";
    public static final String ENERGY_DISCIPLINE_ROUTE_CONTENT_VERSION =
            "chapter-1-v16";
    public static final String STEADY_STEP_ROUTE_CONTENT_VERSION =
            "chapter-1-v17";
    public static final String EXPEDITION_ID = "starter-expedition-v1";
    public static final int LEGACY_NODE_COUNT = 18;
    public static final int NODE_COUNT = 19;
    public static final int STORM_RIFT_NODE_COUNT = 20;
    public static final int VOID_ORCHARD_NODE_COUNT = 22;
    public static final int PRISM_SEXTANT_NODE_COUNT = 23;
    public static final int SECOND_DAWN_NODE_COUNT = 24;
    public static final int UNCHARTED_VERGE_NODE_COUNT = 25;
    public static final int ADULT_PET_FRONTIER_NODE_COUNT = 26;
    public static final int SIGNAL_READER_SECRET_ROUTE_NODE_COUNT = 27;
    public static final int TRAIL_MEMORY_ROUTE_NODE_COUNT = 28;
    public static final int ENERGY_DISCIPLINE_ROUTE_NODE_COUNT = 29;
    public static final int STEADY_STEP_ROUTE_NODE_COUNT = 30;

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
    public static final String CALIBRATED_SEXTANT_CHOICE_ID =
            "trace-second-dawn";
    public static final String HORIZON_SPIRE_NODE_ID = "horizon-spire";
    public static final String FINAL_NODE_ID = "dawn-relay";
    public static final String FINAL_EVENT_ID = "dawn-relay-v1";
    public static final String SECOND_DAWN_ROUTE_CHOICE_ID =
            "open-second-dawn";
    public static final String SECOND_DAWN_NODE_ID = "second-dawn-threshold";
    public static final String SECOND_DAWN_EVENT_ID =
            "second-dawn-threshold-v1";
    public static final String UNCHARTED_VERGE_ROUTE_CHOICE_ID =
            "cross-uncharted-verge";
    public static final String UNCHARTED_VERGE_NODE_ID = "uncharted-verge";
    public static final String UNCHARTED_VERGE_EVENT_ID =
            "uncharted-verge-v1";
    public static final String SPARK_UNCHARTED_CHOICE_ID =
            "ignite-star-trail";
    public static final String MOSS_UNCHARTED_CHOICE_ID =
            "root-return-beacon";
    public static final String RUNE_UNCHARTED_CHOICE_ID =
            "decode-living-constellation";
    public static final String SPARK_ADULT_FRONTIER_CHOICE_ID =
            "ignite-constellation-gate";
    public static final String MOSS_ADULT_FRONTIER_CHOICE_ID =
            "root-constellation-gate";
    public static final String RUNE_ADULT_FRONTIER_CHOICE_ID =
            "read-constellation-gate";
    public static final String CONSTELLATION_SANCTUARY_NODE_ID =
            "constellation-sanctuary";
    public static final String CONSTELLATION_SANCTUARY_EVENT_ID =
            "constellation-sanctuary-v1";
    public static final String SIGNAL_READER_SANCTUARY_CHOICE_ID =
            "decode-sanctuary-signal";
    public static final String HIDDEN_SIGNAL_OBSERVATORY_NODE_ID =
            "hidden-signal-observatory";
    public static final String HIDDEN_SIGNAL_OBSERVATORY_EVENT_ID =
            "hidden-signal-observatory-v1";
    public static final String CHART_HIDDEN_SECTOR_CHOICE_ID =
            "chart-hidden-sector";
    public static final String PRESERVE_ECHO_KEY_CHOICE_ID =
            "preserve-echo-key";
    public static final String RECONSTRUCT_FORGOTTEN_ROUTE_CHOICE_ID =
            "reconstruct-forgotten-route";
    public static final String MEMORY_CONSTELLATION_NODE_ID =
            "memory-constellation";
    public static final String MEMORY_CONSTELLATION_EVENT_ID =
            "memory-constellation-v1";
    public static final String ARCHIVE_RETURN_PATH_CHOICE_ID =
            "archive-return-path";
    public static final String ENTRUST_MEMORY_TO_PET_CHOICE_ID =
            "entrust-memory-to-pet";
    public static final String STABILIZE_DAWN_CURRENT_CHOICE_ID =
            "stabilize-dawn-current";
    public static final String DAWN_MERIDIAN_NODE_ID = "dawn-meridian";
    public static final String DAWN_MERIDIAN_EVENT_ID = "dawn-meridian-v1";
    public static final String ANCHOR_DAWN_FLOW_CHOICE_ID =
            "anchor-dawn-flow";
    public static final String SHARE_DAWN_FLOW_WITH_PET_CHOICE_ID =
            "share-dawn-flow-with-pet";
    public static final String CROSS_FIRST_LIGHT_CAUSEWAY_CHOICE_ID =
            "cross-first-light-causeway";
    public static final String FIRST_LIGHT_CAUSEWAY_NODE_ID =
            "first-light-causeway";
    public static final String FIRST_LIGHT_CAUSEWAY_EVENT_ID =
            "first-light-causeway-v1";
    public static final String MAP_FIRST_LIGHT_PULSE_CHOICE_ID =
            "map-first-light-pulse";
    public static final String FOLLOW_PETS_STEADY_PACE_CHOICE_ID =
            "follow-pets-steady-pace";

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
                new NodeSpec(FINAL_NODE_ID, "Ретранслятор рассвета", 130, FINAL_EVENT_ID,
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
                    STEADY_STEP_ROUTE_CONTENT_VERSION,
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

        NodeSpec secondDawnSpec = new NodeSpec(
                SECOND_DAWN_NODE_ID,
                "Порог второго рассвета",
                60,
                SECOND_DAWN_EVENT_ID,
                "Свет за пределом главы",
                "Ретранслятор открыл короткое окно в ещё не нанесённый на карту сектор."
        );
        ExpeditionDefinition secondDawnDefinition = definition(secondDawnSpec);
        definitions.add(secondDawnDefinition);
        byId.put(secondDawnDefinition.currentNodeId(), secondDawnDefinition);
        byEvent.put(secondDawnDefinition.event().eventId(), secondDawnDefinition);
        choices.put(
                SECOND_DAWN_EVENT_ID,
                secondDawnChoices(inventoryContent)
        );

        choiceNext.put(
                new EventChoiceKey(
                        FINAL_EVENT_ID,
                        SECOND_DAWN_ROUTE_CHOICE_ID
                ),
                secondDawnDefinition
        );
        List<ExpeditionEventChoiceDefinition> dawnRelayChoices = new ArrayList<>(
                choices.get(FINAL_EVENT_ID)
        );
        dawnRelayChoices.add(secondDawnRouteChoice(inventoryContent));
        choices.put(FINAL_EVENT_ID, List.copyOf(dawnRelayChoices));

        NodeSpec unchartedVergeSpec = new NodeSpec(
                UNCHARTED_VERGE_NODE_ID,
                "Неизведанный рубеж",
                70,
                UNCHARTED_VERGE_EVENT_ID,
                "Созвездие без имени",
                "За вторым рассветом секстант удерживает путь среди звёзд, которых ещё нет ни на одной карте."
        );
        ExpeditionDefinition unchartedVergeDefinition = definition(
                unchartedVergeSpec
        );
        definitions.add(unchartedVergeDefinition);
        byId.put(
                unchartedVergeDefinition.currentNodeId(),
                unchartedVergeDefinition
        );
        byEvent.put(
                unchartedVergeDefinition.event().eventId(),
                unchartedVergeDefinition
        );
        choices.put(
                UNCHARTED_VERGE_EVENT_ID,
                unchartedVergeChoices(inventoryContent)
        );

        choiceNext.put(
                new EventChoiceKey(
                        SECOND_DAWN_EVENT_ID,
                        UNCHARTED_VERGE_ROUTE_CHOICE_ID
                ),
                unchartedVergeDefinition
        );
        List<ExpeditionEventChoiceDefinition> secondDawnRouteChoices =
                new ArrayList<>(choices.get(SECOND_DAWN_EVENT_ID));
        secondDawnRouteChoices.add(unchartedVergeRouteChoice(inventoryContent));
        choices.put(
                SECOND_DAWN_EVENT_ID,
                List.copyOf(secondDawnRouteChoices)
        );

        NodeSpec constellationSanctuarySpec = new NodeSpec(
                CONSTELLATION_SANCTUARY_NODE_ID,
                "Святилище созвездий",
                80,
                CONSTELLATION_SANCTUARY_EVENT_ID,
                "Хор трёх путей",
                "Взрослый питомец открыл место, где свет, корни и эхо складываются в карту следующего мира."
        );
        ExpeditionDefinition constellationSanctuaryDefinition = definition(
                constellationSanctuarySpec
        );
        definitions.add(constellationSanctuaryDefinition);
        byId.put(
                constellationSanctuaryDefinition.currentNodeId(),
                constellationSanctuaryDefinition
        );
        byEvent.put(
                constellationSanctuaryDefinition.event().eventId(),
                constellationSanctuaryDefinition
        );
        choices.put(
                CONSTELLATION_SANCTUARY_EVENT_ID,
                constellationSanctuaryChoices(inventoryContent)
        );

        for (String choiceId : List.of(
                SPARK_ADULT_FRONTIER_CHOICE_ID,
                MOSS_ADULT_FRONTIER_CHOICE_ID,
                RUNE_ADULT_FRONTIER_CHOICE_ID
        )) {
            choiceNext.put(
                    new EventChoiceKey(UNCHARTED_VERGE_EVENT_ID, choiceId),
                    constellationSanctuaryDefinition
            );
        }
        List<ExpeditionEventChoiceDefinition> adultFrontierChoices =
                new ArrayList<>(choices.get(UNCHARTED_VERGE_EVENT_ID));
        adultFrontierChoices.addAll(adultPetFrontierChoices(inventoryContent));
        choices.put(
                UNCHARTED_VERGE_EVENT_ID,
                List.copyOf(adultFrontierChoices)
        );

        NodeSpec hiddenSignalObservatorySpec = new NodeSpec(
                HIDDEN_SIGNAL_OBSERVATORY_NODE_ID,
                "Обсерватория скрытого сигнала",
                90,
                HIDDEN_SIGNAL_OBSERVATORY_EVENT_ID,
                "Координаты за хором",
                "За общей песней святилища открылся безмолвный сектор, где один сигнал ждёт новой карты."
        );
        ExpeditionDefinition hiddenSignalObservatoryDefinition = definition(
                hiddenSignalObservatorySpec
        );
        definitions.add(hiddenSignalObservatoryDefinition);
        byId.put(
                hiddenSignalObservatoryDefinition.currentNodeId(),
                hiddenSignalObservatoryDefinition
        );
        byEvent.put(
                hiddenSignalObservatoryDefinition.event().eventId(),
                hiddenSignalObservatoryDefinition
        );
        choices.put(
                HIDDEN_SIGNAL_OBSERVATORY_EVENT_ID,
                hiddenSignalObservatoryChoices(inventoryContent)
        );
        choiceNext.put(
                new EventChoiceKey(
                        CONSTELLATION_SANCTUARY_EVENT_ID,
                        SIGNAL_READER_SANCTUARY_CHOICE_ID
                ),
                hiddenSignalObservatoryDefinition
        );

        NodeSpec memoryConstellationSpec = new NodeSpec(
                MEMORY_CONSTELLATION_NODE_ID,
                "Созвездие памяти",
                95,
                MEMORY_CONSTELLATION_EVENT_ID,
                "Маршрут, который помнит шаги",
                "Забытые следы вспыхнули созвездием и ждут решения: сохранить карту или доверить память живому проводнику."
        );
        ExpeditionDefinition memoryConstellationDefinition = definition(
                memoryConstellationSpec
        );
        definitions.add(memoryConstellationDefinition);
        byId.put(
                memoryConstellationDefinition.currentNodeId(),
                memoryConstellationDefinition
        );
        byEvent.put(
                memoryConstellationDefinition.event().eventId(),
                memoryConstellationDefinition
        );
        choices.put(
                MEMORY_CONSTELLATION_EVENT_ID,
                memoryConstellationChoices(inventoryContent)
        );
        choiceNext.put(
                new EventChoiceKey(
                        HIDDEN_SIGNAL_OBSERVATORY_EVENT_ID,
                        RECONSTRUCT_FORGOTTEN_ROUTE_CHOICE_ID
                ),
                memoryConstellationDefinition
        );

        NodeSpec dawnMeridianSpec = new NodeSpec(
                DAWN_MERIDIAN_NODE_ID,
                "Меридиан рассвета",
                100,
                DAWN_MERIDIAN_EVENT_ID,
                "Ритм между шагами",
                "Созвездие памяти выпустило поток рассвета. Его можно закрепить в маяках или разделить с живым проводником."
        );
        ExpeditionDefinition dawnMeridianDefinition = definition(
                dawnMeridianSpec
        );
        definitions.add(dawnMeridianDefinition);
        byId.put(
                dawnMeridianDefinition.currentNodeId(),
                dawnMeridianDefinition
        );
        byEvent.put(
                dawnMeridianDefinition.event().eventId(),
                dawnMeridianDefinition
        );
        choices.put(
                DAWN_MERIDIAN_EVENT_ID,
                dawnMeridianChoices(inventoryContent)
        );
        choiceNext.put(
                new EventChoiceKey(
                        MEMORY_CONSTELLATION_EVENT_ID,
                        STABILIZE_DAWN_CURRENT_CHOICE_ID
                ),
                dawnMeridianDefinition
        );

        NodeSpec firstLightCausewaySpec = new NodeSpec(
                FIRST_LIGHT_CAUSEWAY_NODE_ID,
                "Переход первого света",
                105,
                FIRST_LIGHT_CAUSEWAY_EVENT_ID,
                "Шаг над рассветом",
                "Меридиан собрал свет в подвижный переход. Его ритм можно нанести на карту или доверить чутью питомца."
        );
        ExpeditionDefinition firstLightCausewayDefinition = definition(
                firstLightCausewaySpec
        );
        definitions.add(firstLightCausewayDefinition);
        byId.put(
                firstLightCausewayDefinition.currentNodeId(),
                firstLightCausewayDefinition
        );
        byEvent.put(
                firstLightCausewayDefinition.event().eventId(),
                firstLightCausewayDefinition
        );
        choices.put(
                FIRST_LIGHT_CAUSEWAY_EVENT_ID,
                firstLightCausewayChoices(inventoryContent)
        );
        choiceNext.put(
                new EventChoiceKey(
                        DAWN_MERIDIAN_EVENT_ID,
                        CROSS_FIRST_LIGHT_CAUSEWAY_CHOICE_ID
                ),
                firstLightCausewayDefinition
        );

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
                STEADY_STEP_ROUTE_CONTENT_VERSION
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
        if (CONSTELLATION_SANCTUARY_EVENT_ID.equals(eventId)
                && SIGNAL_READER_SANCTUARY_CHOICE_ID.equals(choiceId)
                && !supportsSignalReaderSecretRoute(activeContentVersion)) {
            explicit = null;
        }
        return explicit == null
                ? nextNodeAfterEvent(eventId)
                : Optional.of(explicit);
    }

    public ExpeditionEventChoiceDefinition requireChoice(
            String eventId,
            String choiceId
    ) {
        return requireChoice(
                eventId,
                choiceId,
                STEADY_STEP_ROUTE_CONTENT_VERSION
        );
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
        return eventChoices(
                eventId,
                STEADY_STEP_ROUTE_CONTENT_VERSION
        );
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
        if (SPECTRUM_OBSERVATORY_EVENT_ID.equals(eventId)
                && !supportsCalibratedSextantChoice(activeContentVersion)) {
            return choices.stream()
                    .filter(choice -> !CALIBRATED_SEXTANT_CHOICE_ID.equals(
                            choice.choiceId()
                    ))
                    .toList();
        }
        if (FINAL_EVENT_ID.equals(eventId)
                && !supportsSecondDawnRoute(activeContentVersion)) {
            return choices.stream()
                    .filter(choice -> !SECOND_DAWN_ROUTE_CHOICE_ID.equals(
                            choice.choiceId()
                    ))
                    .toList();
        }
        if (SECOND_DAWN_EVENT_ID.equals(eventId)
                && !supportsUnchartedVerge(activeContentVersion)) {
            return choices.stream()
                    .filter(choice -> !UNCHARTED_VERGE_ROUTE_CHOICE_ID.equals(
                            choice.choiceId()
                    ))
                    .toList();
        }
        if (UNCHARTED_VERGE_EVENT_ID.equals(eventId)) {
            var filtered = choices.stream();
            if (!supportsPetGuidedUncharted(activeContentVersion)) {
                filtered = filtered
                        .filter(choice -> !SPARK_UNCHARTED_CHOICE_ID.equals(
                                choice.choiceId()
                        ))
                        .filter(choice -> !MOSS_UNCHARTED_CHOICE_ID.equals(
                                choice.choiceId()
                        ))
                        .filter(choice -> !RUNE_UNCHARTED_CHOICE_ID.equals(
                                choice.choiceId()
                        ));
            }
            if (!supportsAdultPetFrontier(activeContentVersion)) {
                filtered = filtered
                        .filter(choice -> !SPARK_ADULT_FRONTIER_CHOICE_ID.equals(
                                choice.choiceId()
                        ))
                        .filter(choice -> !MOSS_ADULT_FRONTIER_CHOICE_ID.equals(
                                choice.choiceId()
                        ))
                        .filter(choice -> !RUNE_ADULT_FRONTIER_CHOICE_ID.equals(
                                choice.choiceId()
                        ));
            }
            return filtered.toList();
        }
        if (CONSTELLATION_SANCTUARY_EVENT_ID.equals(eventId)) {
            if (!supportsAdultPetFrontier(activeContentVersion)) {
                return List.of();
            }
            if (!supportsPilotSkillChoice(activeContentVersion)) {
                return choices.stream()
                        .filter(choice -> !SIGNAL_READER_SANCTUARY_CHOICE_ID
                                .equals(choice.choiceId()))
                        .toList();
            }
        }
        if (HIDDEN_SIGNAL_OBSERVATORY_EVENT_ID.equals(eventId)
                && !supportsTrailMemoryRoute(activeContentVersion)) {
            return choices.stream()
                    .filter(choice -> !RECONSTRUCT_FORGOTTEN_ROUTE_CHOICE_ID
                            .equals(choice.choiceId()))
                    .toList();
        }
        if (MEMORY_CONSTELLATION_EVENT_ID.equals(eventId)
                && !supportsEnergyDisciplineRoute(activeContentVersion)) {
            return choices.stream()
                    .filter(choice -> !STABILIZE_DAWN_CURRENT_CHOICE_ID.equals(
                            choice.choiceId()
                    ))
                    .toList();
        }
        if (DAWN_MERIDIAN_EVENT_ID.equals(eventId)
                && !supportsSteadyStepRoute(activeContentVersion)) {
            return choices.stream()
                    .filter(choice -> !CROSS_FIRST_LIGHT_CAUSEWAY_CHOICE_ID
                            .equals(choice.choiceId()))
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
        return STEADY_STEP_ROUTE_CONTENT_VERSION;
    }

    public String contentVersion(boolean resonanceRouteActive) {
        return resonanceRouteActive ? CONTENT_VERSION : LEGACY_CONTENT_VERSION;
    }

    public String activeContentVersion(ExpeditionContentActivation activation) {
        String activeContentVersion = activation.activeContentVersion();
        if (STEADY_STEP_ROUTE_CONTENT_VERSION.equals(activeContentVersion)) {
            return STEADY_STEP_ROUTE_CONTENT_VERSION;
        }
        if (ENERGY_DISCIPLINE_ROUTE_CONTENT_VERSION.equals(
                activeContentVersion
        )) {
            return ENERGY_DISCIPLINE_ROUTE_CONTENT_VERSION;
        }
        if (TRAIL_MEMORY_ROUTE_CONTENT_VERSION.equals(activeContentVersion)) {
            return TRAIL_MEMORY_ROUTE_CONTENT_VERSION;
        }
        if (SIGNAL_READER_SECRET_ROUTE_CONTENT_VERSION.equals(
                activeContentVersion
        )) {
            return SIGNAL_READER_SECRET_ROUTE_CONTENT_VERSION;
        }
        if (PILOT_SKILL_CHOICE_CONTENT_VERSION.equals(activeContentVersion)) {
            return PILOT_SKILL_CHOICE_CONTENT_VERSION;
        }
        if (ADULT_PET_FRONTIER_CONTENT_VERSION.equals(
                activeContentVersion
        )) {
            return ADULT_PET_FRONTIER_CONTENT_VERSION;
        }
        if (ADULT_PET_EVOLUTION_CONTENT_VERSION.equals(
                activeContentVersion
        )) {
            return ADULT_PET_EVOLUTION_CONTENT_VERSION;
        }
        if (PET_GUIDED_UNCHARTED_CONTENT_VERSION.equals(
                activeContentVersion
        )) {
            return PET_GUIDED_UNCHARTED_CONTENT_VERSION;
        }
        if (UNCHARTED_VERGE_CONTENT_VERSION.equals(activeContentVersion)) {
            return UNCHARTED_VERGE_CONTENT_VERSION;
        }
        if (SECOND_DAWN_ATTUNEMENT_CONTENT_VERSION.equals(
                activeContentVersion
        )) {
            return SECOND_DAWN_ATTUNEMENT_CONTENT_VERSION;
        }
        if (SECOND_DAWN_CONTENT_VERSION.equals(activeContentVersion)) {
            return SECOND_DAWN_CONTENT_VERSION;
        }
        if (CALIBRATED_SEXTANT_CONTENT_VERSION.equals(activeContentVersion)) {
            return CALIBRATED_SEXTANT_CONTENT_VERSION;
        }
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
                || PRISM_SEXTANT_CONTENT_VERSION.equals(contentVersion)
                || CALIBRATED_SEXTANT_CONTENT_VERSION.equals(contentVersion)
                || SECOND_DAWN_CONTENT_VERSION.equals(contentVersion)
                || SECOND_DAWN_ATTUNEMENT_CONTENT_VERSION.equals(
                        contentVersion
                )
                || UNCHARTED_VERGE_CONTENT_VERSION.equals(contentVersion)
                || PET_GUIDED_UNCHARTED_CONTENT_VERSION.equals(contentVersion)
                || ADULT_PET_EVOLUTION_CONTENT_VERSION.equals(contentVersion)
                || ADULT_PET_FRONTIER_CONTENT_VERSION.equals(contentVersion)
                || PILOT_SKILL_CHOICE_CONTENT_VERSION.equals(contentVersion)
                || SIGNAL_READER_SECRET_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                )
                || TRAIL_MEMORY_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                )
                || ENERGY_DISCIPLINE_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                )
                || STEADY_STEP_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                );
    }

    public static boolean supportsStormRift(String contentVersion) {
        return STORM_RIFT_CONTENT_VERSION.equals(contentVersion)
                || VOID_ORCHARD_CONTENT_VERSION.equals(contentVersion)
                || PRISM_SEXTANT_CONTENT_VERSION.equals(contentVersion)
                || CALIBRATED_SEXTANT_CONTENT_VERSION.equals(contentVersion)
                || SECOND_DAWN_CONTENT_VERSION.equals(contentVersion)
                || SECOND_DAWN_ATTUNEMENT_CONTENT_VERSION.equals(
                        contentVersion
                )
                || UNCHARTED_VERGE_CONTENT_VERSION.equals(contentVersion)
                || PET_GUIDED_UNCHARTED_CONTENT_VERSION.equals(contentVersion)
                || ADULT_PET_EVOLUTION_CONTENT_VERSION.equals(contentVersion)
                || ADULT_PET_FRONTIER_CONTENT_VERSION.equals(contentVersion)
                || PILOT_SKILL_CHOICE_CONTENT_VERSION.equals(contentVersion)
                || SIGNAL_READER_SECRET_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                )
                || TRAIL_MEMORY_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                )
                || ENERGY_DISCIPLINE_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                )
                || STEADY_STEP_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                );
    }

    public static boolean supportsVoidOrchardFork(String contentVersion) {
        return VOID_ORCHARD_CONTENT_VERSION.equals(contentVersion)
                || PRISM_SEXTANT_CONTENT_VERSION.equals(contentVersion)
                || CALIBRATED_SEXTANT_CONTENT_VERSION.equals(contentVersion)
                || SECOND_DAWN_CONTENT_VERSION.equals(contentVersion)
                || SECOND_DAWN_ATTUNEMENT_CONTENT_VERSION.equals(
                        contentVersion
                )
                || UNCHARTED_VERGE_CONTENT_VERSION.equals(contentVersion)
                || PET_GUIDED_UNCHARTED_CONTENT_VERSION.equals(contentVersion)
                || ADULT_PET_EVOLUTION_CONTENT_VERSION.equals(contentVersion)
                || ADULT_PET_FRONTIER_CONTENT_VERSION.equals(contentVersion)
                || PILOT_SKILL_CHOICE_CONTENT_VERSION.equals(contentVersion)
                || SIGNAL_READER_SECRET_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                )
                || TRAIL_MEMORY_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                )
                || ENERGY_DISCIPLINE_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                )
                || STEADY_STEP_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                );
    }

    public static boolean supportsPrismSextantRoute(String contentVersion) {
        return PRISM_SEXTANT_CONTENT_VERSION.equals(contentVersion)
                || CALIBRATED_SEXTANT_CONTENT_VERSION.equals(contentVersion)
                || SECOND_DAWN_CONTENT_VERSION.equals(contentVersion)
                || SECOND_DAWN_ATTUNEMENT_CONTENT_VERSION.equals(
                        contentVersion
                )
                || UNCHARTED_VERGE_CONTENT_VERSION.equals(contentVersion)
                || PET_GUIDED_UNCHARTED_CONTENT_VERSION.equals(contentVersion)
                || ADULT_PET_EVOLUTION_CONTENT_VERSION.equals(contentVersion)
                || ADULT_PET_FRONTIER_CONTENT_VERSION.equals(contentVersion)
                || PILOT_SKILL_CHOICE_CONTENT_VERSION.equals(contentVersion)
                || SIGNAL_READER_SECRET_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                )
                || TRAIL_MEMORY_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                )
                || ENERGY_DISCIPLINE_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                )
                || STEADY_STEP_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                );
    }

    public static boolean supportsCalibratedSextantChoice(
            String contentVersion
    ) {
        return CALIBRATED_SEXTANT_CONTENT_VERSION.equals(contentVersion)
                || SECOND_DAWN_CONTENT_VERSION.equals(contentVersion)
                || SECOND_DAWN_ATTUNEMENT_CONTENT_VERSION.equals(
                        contentVersion
                )
                || UNCHARTED_VERGE_CONTENT_VERSION.equals(contentVersion)
                || PET_GUIDED_UNCHARTED_CONTENT_VERSION.equals(contentVersion)
                || ADULT_PET_EVOLUTION_CONTENT_VERSION.equals(contentVersion)
                || ADULT_PET_FRONTIER_CONTENT_VERSION.equals(contentVersion)
                || PILOT_SKILL_CHOICE_CONTENT_VERSION.equals(contentVersion)
                || SIGNAL_READER_SECRET_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                )
                || TRAIL_MEMORY_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                )
                || ENERGY_DISCIPLINE_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                )
                || STEADY_STEP_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                );
    }

    public static boolean supportsSecondDawnRoute(String contentVersion) {
        return SECOND_DAWN_CONTENT_VERSION.equals(contentVersion)
                || SECOND_DAWN_ATTUNEMENT_CONTENT_VERSION.equals(
                        contentVersion
                )
                || UNCHARTED_VERGE_CONTENT_VERSION.equals(contentVersion)
                || PET_GUIDED_UNCHARTED_CONTENT_VERSION.equals(contentVersion)
                || ADULT_PET_EVOLUTION_CONTENT_VERSION.equals(contentVersion)
                || ADULT_PET_FRONTIER_CONTENT_VERSION.equals(contentVersion)
                || PILOT_SKILL_CHOICE_CONTENT_VERSION.equals(contentVersion)
                || SIGNAL_READER_SECRET_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                )
                || TRAIL_MEMORY_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                )
                || ENERGY_DISCIPLINE_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                )
                || STEADY_STEP_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                );
    }

    public static boolean supportsSecondDawnAttunement(
            String contentVersion
    ) {
        return SECOND_DAWN_ATTUNEMENT_CONTENT_VERSION.equals(contentVersion)
                || UNCHARTED_VERGE_CONTENT_VERSION.equals(contentVersion)
                || PET_GUIDED_UNCHARTED_CONTENT_VERSION.equals(contentVersion)
                || ADULT_PET_EVOLUTION_CONTENT_VERSION.equals(contentVersion)
                || ADULT_PET_FRONTIER_CONTENT_VERSION.equals(contentVersion)
                || PILOT_SKILL_CHOICE_CONTENT_VERSION.equals(contentVersion)
                || SIGNAL_READER_SECRET_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                )
                || TRAIL_MEMORY_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                )
                || ENERGY_DISCIPLINE_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                )
                || STEADY_STEP_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                );
    }

    public static boolean supportsUnchartedVerge(String contentVersion) {
        return UNCHARTED_VERGE_CONTENT_VERSION.equals(contentVersion)
                || PET_GUIDED_UNCHARTED_CONTENT_VERSION.equals(contentVersion)
                || ADULT_PET_EVOLUTION_CONTENT_VERSION.equals(contentVersion)
                || ADULT_PET_FRONTIER_CONTENT_VERSION.equals(contentVersion)
                || PILOT_SKILL_CHOICE_CONTENT_VERSION.equals(contentVersion)
                || SIGNAL_READER_SECRET_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                )
                || TRAIL_MEMORY_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                )
                || ENERGY_DISCIPLINE_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                )
                || STEADY_STEP_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                );
    }

    public static boolean supportsPetGuidedUncharted(String contentVersion) {
        return PET_GUIDED_UNCHARTED_CONTENT_VERSION.equals(contentVersion)
                || ADULT_PET_EVOLUTION_CONTENT_VERSION.equals(contentVersion)
                || ADULT_PET_FRONTIER_CONTENT_VERSION.equals(contentVersion)
                || PILOT_SKILL_CHOICE_CONTENT_VERSION.equals(contentVersion)
                || SIGNAL_READER_SECRET_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                )
                || TRAIL_MEMORY_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                )
                || ENERGY_DISCIPLINE_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                )
                || STEADY_STEP_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                );
    }

    public static boolean supportsAdultPetEvolution(String contentVersion) {
        return ADULT_PET_EVOLUTION_CONTENT_VERSION.equals(contentVersion)
                || ADULT_PET_FRONTIER_CONTENT_VERSION.equals(contentVersion)
                || PILOT_SKILL_CHOICE_CONTENT_VERSION.equals(contentVersion)
                || SIGNAL_READER_SECRET_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                )
                || TRAIL_MEMORY_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                )
                || ENERGY_DISCIPLINE_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                )
                || STEADY_STEP_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                );
    }

    public static boolean supportsAdultPetFrontier(String contentVersion) {
        return ADULT_PET_FRONTIER_CONTENT_VERSION.equals(contentVersion)
                || PILOT_SKILL_CHOICE_CONTENT_VERSION.equals(contentVersion)
                || SIGNAL_READER_SECRET_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                )
                || TRAIL_MEMORY_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                )
                || ENERGY_DISCIPLINE_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                )
                || STEADY_STEP_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                );
    }

    public static boolean supportsPilotSkillChoice(String contentVersion) {
        return PILOT_SKILL_CHOICE_CONTENT_VERSION.equals(contentVersion)
                || SIGNAL_READER_SECRET_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                )
                || TRAIL_MEMORY_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                )
                || ENERGY_DISCIPLINE_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                )
                || STEADY_STEP_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                );
    }

    public static boolean supportsSignalReaderSecretRoute(
            String contentVersion
    ) {
        return SIGNAL_READER_SECRET_ROUTE_CONTENT_VERSION.equals(
                contentVersion
        ) || TRAIL_MEMORY_ROUTE_CONTENT_VERSION.equals(
                contentVersion
        ) || ENERGY_DISCIPLINE_ROUTE_CONTENT_VERSION.equals(
                contentVersion
        ) || STEADY_STEP_ROUTE_CONTENT_VERSION.equals(
                contentVersion
        );
    }

    public static boolean supportsTrailMemoryRoute(String contentVersion) {
        return TRAIL_MEMORY_ROUTE_CONTENT_VERSION.equals(contentVersion)
                || ENERGY_DISCIPLINE_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                )
                || STEADY_STEP_ROUTE_CONTENT_VERSION.equals(
                        contentVersion
                );
    }

    public static boolean supportsEnergyDisciplineRoute(
            String contentVersion
    ) {
        return ENERGY_DISCIPLINE_ROUTE_CONTENT_VERSION.equals(contentVersion)
                || STEADY_STEP_ROUTE_CONTENT_VERSION.equals(contentVersion);
    }

    public static boolean supportsSteadyStepRoute(String contentVersion) {
        return STEADY_STEP_ROUTE_CONTENT_VERSION.equals(contentVersion);
    }

    private ExpeditionDefinition definition(NodeSpec spec) {
        return new ExpeditionDefinition(
                STEADY_STEP_ROUTE_CONTENT_VERSION,
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
                ),
                new ExpeditionEventChoiceDefinition(
                        CALIBRATED_SEXTANT_CHOICE_ID,
                        "Проследить второй рассвет",
                        "Использовать точную калибровку секстанта, чтобы удержать самый тонкий луч за границей спектра.",
                        "Карта второго рассвета",
                        "Откалиброванный секстант закрепил невидимую дугу и вывел отряд к свету следующего горизонта.",
                        46,
                        24,
                        reward(
                                inventoryContent,
                                StarterInventoryContent.DAWN_FRAGMENT_ID,
                                3
                        ),
                        new ExpeditionChoiceEquipmentRequirement(
                                StarterEquipmentContent.NAVIGATION_SLOT_ID,
                                "Навигационный прибор",
                                inventoryContent.require(
                                        StarterInventoryContent.PRISM_SEXTANT_ID
                                ),
                                2,
                                "Экипируйте откалиброванный призматический секстант уровня 2, чтобы увидеть второй рассвет."
                        )
                )
        );
    }

    private ExpeditionEventChoiceDefinition secondDawnRouteChoice(
            StarterInventoryContent inventoryContent
    ) {
        return new ExpeditionEventChoiceDefinition(
                SECOND_DAWN_ROUTE_CHOICE_ID,
                "Направить ретранслятор ко второму рассвету",
                "Совместить точную карту секстанта с финальным импульсом главы.",
                "Окно второго рассвета",
                "Откалиброванный секстант удержал новый горизонт, пока ретранслятор открывал короткий переход.",
                48,
                26,
                reward(
                        inventoryContent,
                        StarterInventoryContent.DAWN_FRAGMENT_ID,
                        1
                ),
                new ExpeditionChoiceEquipmentRequirement(
                        StarterEquipmentContent.NAVIGATION_SLOT_ID,
                        "Навигационный прибор",
                        inventoryContent.require(
                                StarterInventoryContent.PRISM_SEXTANT_ID
                        ),
                        2,
                        "Экипируйте откалиброванный призматический секстант уровня 2, чтобы открыть второй рассвет."
                )
        );
    }

    private List<ExpeditionEventChoiceDefinition> secondDawnChoices(
            StarterInventoryContent inventoryContent
    ) {
        return List.of(
                new ExpeditionEventChoiceDefinition(
                        "anchor-second-dawn",
                        "Закрепить новый горизонт",
                        "Нанести устойчивые точки перехода на карту следующей главы.",
                        "Граница нанесена на карту",
                        "Пилот закрепил координаты второго рассвета и собрал ионный заряд с опорных маяков.",
                        60,
                        22,
                        reward(
                                inventoryContent,
                                StarterInventoryContent.ION_BLOOM_ID,
                                2
                        )
                ),
                new ExpeditionEventChoiceDefinition(
                        "leap-beyond-dawn",
                        "Шагнуть за рассвет вместе",
                        "Доверить питомцу первый след в ещё не исследованном секторе.",
                        "Шаг за пределы",
                        "Питомец удержал живой след за границей карты и вернул два фрагмента нового света.",
                        42,
                        34,
                        reward(
                                inventoryContent,
                                StarterInventoryContent.DAWN_FRAGMENT_ID,
                                2
                        )
                )
        );
    }

    private ExpeditionEventChoiceDefinition unchartedVergeRouteChoice(
            StarterInventoryContent inventoryContent
    ) {
        return new ExpeditionEventChoiceDefinition(
                UNCHARTED_VERGE_ROUTE_CHOICE_ID,
                "Пересечь неизведанный рубеж",
                "Настроить EPIC-секстант на созвездие за вторым рассветом и удержать обратный путь.",
                "Курс за пределы карты",
                "Настроенный секстант связал безымянные звёзды в устойчивый маршрут к неизведанному рубежу.",
                58,
                32,
                reward(
                        inventoryContent,
                        StarterInventoryContent.ECHO_THREAD_ID,
                        2
                ),
                new ExpeditionChoiceEquipmentRequirement(
                        StarterEquipmentContent.NAVIGATION_SLOT_ID,
                        "Навигационный прибор",
                        inventoryContent.require(
                                StarterInventoryContent.PRISM_SEXTANT_ID
                        ),
                        3,
                        "Экипируйте настроенный призматический секстант уровня 3, чтобы пересечь неизведанный рубеж."
                )
        );
    }

    private List<ExpeditionEventChoiceDefinition> unchartedVergeChoices(
            StarterInventoryContent inventoryContent
    ) {
        return List.of(
                new ExpeditionEventChoiceDefinition(
                        "deploy-return-beacon",
                        "Развернуть маяк возврата",
                        "Закрепить путь домой и отметить первую безопасную точку нового сектора.",
                        "Маяк на новой карте",
                        "Пилот развернул опорный маяк и собрал призматическую пыль с границы устойчивого маршрута.",
                        72,
                        28,
                        reward(
                                inventoryContent,
                                StarterInventoryContent.PRISM_DUST_ID,
                                3
                        )
                ),
                new ExpeditionEventChoiceDefinition(
                        "follow-living-constellation",
                        "Последовать за живым созвездием",
                        "Доверить питомцу звёздный узор, который меняется с каждым шагом.",
                        "След живого неба",
                        "Питомец запомнил первый путь нового сектора и вернул свет трёх ещё не открытых рассветов.",
                        50,
                        42,
                        reward(
                                inventoryContent,
                                StarterInventoryContent.DAWN_FRAGMENT_ID,
                                3
                        )
                ),
                new ExpeditionEventChoiceDefinition(
                        SPARK_UNCHARTED_CHOICE_ID,
                        "Зажечь звёздный след с Искрой",
                        "Позволить Искре превратить безымянные огни в живую тропу.",
                        "След Искры",
                        "Искра связала далёкие вспышки в яркий маршрут и принесла заряд нового неба.",
                        48,
                        46,
                        reward(
                                inventoryContent,
                                StarterInventoryContent.ION_BLOOM_ID,
                                3
                        ),
                        new ExpeditionChoicePetRequirement(
                                StarterProgressionContent.PET_ID,
                                "Искра",
                                "Выберите Искру активным питомцем, чтобы зажечь звёздный след."
                        )
                ),
                new ExpeditionEventChoiceDefinition(
                        MOSS_UNCHARTED_CHOICE_ID,
                        "Укоренить маяк вместе с Мхом",
                        "Доверить Мху опорную точку на незнакомой земле.",
                        "Корни нового рубежа",
                        "Мох укрепил маяк живыми корнями и сохранил семена для следующего перехода.",
                        64,
                        34,
                        reward(
                                inventoryContent,
                                StarterInventoryContent.ASH_SEED_ID,
                                3
                        ),
                        new ExpeditionChoicePetRequirement(
                                StarterProgressionContent.MOSS_PET_ID,
                                "Мох",
                                "Выберите Мха активным питомцем, чтобы укоренить маяк возврата."
                        )
                ),
                new ExpeditionEventChoiceDefinition(
                        RUNE_UNCHARTED_CHOICE_ID,
                        "Расшифровать созвездие с Навигатором",
                        "Позволить Навигатору услышать ритм между безымянными звёздами.",
                        "Эхо живого созвездия",
                        "Навигатор прочитал небесный ритм и вплёл новый маршрут в нити эха.",
                        56,
                        40,
                        reward(
                                inventoryContent,
                                StarterInventoryContent.ECHO_THREAD_ID,
                                3
                        ),
                        new ExpeditionChoicePetRequirement(
                                StarterProgressionContent.RUNE_PET_ID,
                                "Навигатор",
                                "Выберите Навигатора активным питомцем, чтобы расшифровать живое созвездие."
                        )
                )
        );
    }

    private List<ExpeditionEventChoiceDefinition> adultPetFrontierChoices(
            StarterInventoryContent inventoryContent
    ) {
        return List.of(
                new ExpeditionEventChoiceDefinition(
                        SPARK_ADULT_FRONTIER_CHOICE_ID,
                        "Зажечь врата с Искрой-звездочётом",
                        "Доверить взрослой Искре звёздную решётку за границей карты.",
                        "Врата звёздного огня",
                        "Искра-звездочёт собрала далёкие вспышки в проход к святилищу созвездий.",
                        54,
                        52,
                        reward(
                                inventoryContent,
                                StarterInventoryContent.ION_BLOOM_ID,
                                2
                        ),
                        new ExpeditionChoicePetRequirement(
                                StarterProgressionContent.PET_ID,
                                "Искра-звездочёт",
                                "Выберите взрослую Искру-звездочёта активным питомцем, чтобы открыть звёздные врата.",
                                2
                        )
                ),
                new ExpeditionEventChoiceDefinition(
                        MOSS_ADULT_FRONTIER_CHOICE_ID,
                        "Укоренить проход с Мхом-оплотом",
                        "Позволить взрослому Мху вырастить опору в пустоте между созвездиями.",
                        "Живой мост за рубеж",
                        "Мох-оплот поднял корневой мост и связал новую землю со святилищем созвездий.",
                        70,
                        40,
                        reward(
                                inventoryContent,
                                StarterInventoryContent.ASH_SEED_ID,
                                2
                        ),
                        new ExpeditionChoicePetRequirement(
                                StarterProgressionContent.MOSS_PET_ID,
                                "Мох-оплот",
                                "Выберите взрослого Мха-оплота активным питомцем, чтобы вырастить живой проход.",
                                2
                        )
                ),
                new ExpeditionEventChoiceDefinition(
                        RUNE_ADULT_FRONTIER_CHOICE_ID,
                        "Прочесть врата с Навигатором созвездий",
                        "Попросить взрослого Навигатора услышать маршрут между ещё не названными звёздами.",
                        "Прочитанный горизонт",
                        "Навигатор созвездий распознал ритм нового неба и открыл путь к святилищу созвездий.",
                        62,
                        46,
                        reward(
                                inventoryContent,
                                StarterInventoryContent.ECHO_THREAD_ID,
                                2
                        ),
                        new ExpeditionChoicePetRequirement(
                                StarterProgressionContent.RUNE_PET_ID,
                                "Навигатор созвездий",
                                "Выберите взрослого Навигатора созвездий активным питомцем, чтобы прочесть скрытые врата.",
                                2
                        )
                )
        );
    }

    private List<ExpeditionEventChoiceDefinition> constellationSanctuaryChoices(
            StarterInventoryContent inventoryContent
    ) {
        return List.of(
                new ExpeditionEventChoiceDefinition(
                        "anchor-constellation-sanctuary",
                        "Закрепить карту трёх путей",
                        "Свести звёздный свет, живые корни и эхо в устойчивую карту следующего мира.",
                        "Три пути стали картой",
                        "Пилот закрепил общий маршрут взрослых питомцев и сохранил призматическую пыль святилища.",
                        82,
                        44,
                        reward(
                                inventoryContent,
                                StarterInventoryContent.PRISM_DUST_ID,
                                3
                        )
                ),
                new ExpeditionEventChoiceDefinition(
                        "carry-sanctuary-song",
                        "Унести песню святилища",
                        "Доверить питомцу живой мотив, который укажет дорогу при следующем переходе.",
                        "Песня нового горизонта",
                        "Питомец запомнил хор святилища и вынес свет трёх будущих рассветов.",
                        68,
                        60,
                        reward(
                                inventoryContent,
                                StarterInventoryContent.DAWN_FRAGMENT_ID,
                                3
                        )
                ),
                new ExpeditionEventChoiceDefinition(
                        SIGNAL_READER_SANCTUARY_CHOICE_ID,
                        "Расшифровать скрытый хор",
                        "Применить Чтение сигналов, чтобы отделить тайный маршрут от общего хора святилища.",
                        "Сигнал за пределами карты",
                        "Пилот распознал в хоре святилища координаты невидимого сектора и сохранил нити его эха.",
                        96,
                        50,
                        reward(
                                inventoryContent,
                                StarterInventoryContent.ECHO_THREAD_ID,
                                4
                        ),
                        new ExpeditionChoiceSkillRequirement(
                                PlatformSkillIds.SIGNAL_READER,
                                "Чтение сигналов",
                                "Откройте навык «Чтение сигналов», чтобы расшифровать скрытый хор святилища."
                        )
                )
        );
    }

    private List<ExpeditionEventChoiceDefinition> hiddenSignalObservatoryChoices(
            StarterInventoryContent inventoryContent
    ) {
        return List.of(
                new ExpeditionEventChoiceDefinition(
                        CHART_HIDDEN_SECTOR_CHOICE_ID,
                        "Нанести скрытый сектор на карту",
                        "Свести координаты хора в устойчивую карту для следующего перехода.",
                        "Сектор получил имя",
                        "Пилот закрепил координаты безмолвного неба и вернул скрытый путь в общую карту.",
                        112,
                        54,
                        reward(
                                inventoryContent,
                                StarterInventoryContent.PRISM_DUST_ID,
                                4
                        )
                ),
                new ExpeditionEventChoiceDefinition(
                        PRESERVE_ECHO_KEY_CHOICE_ID,
                        "Сохранить ключ эха",
                        "Передать питомцу живой ключ сигнала, не раскрывая сектор до следующей главы.",
                        "Ключ будущего маршрута",
                        "Питомец удержал тихий ритм сектора и сохранил его в нитях эха для будущего пути.",
                        86,
                        76,
                        reward(
                                inventoryContent,
                                StarterInventoryContent.ECHO_THREAD_ID,
                                5
                        )
                ),
                new ExpeditionEventChoiceDefinition(
                        RECONSTRUCT_FORGOTTEN_ROUTE_CHOICE_ID,
                        "Восстановить забытый маршрут",
                        "Применить Память маршрута и собрать исчезнувшие шаги в новый путь.",
                        "Следы снова стали дорогой",
                        "Пилот связал отголоски пройденных узлов и открыл созвездие, которое помнит каждый шаг.",
                        104,
                        64,
                        reward(
                                inventoryContent,
                                StarterInventoryContent.DAWN_FRAGMENT_ID,
                                3
                        ),
                        new ExpeditionChoiceSkillRequirement(
                                PlatformSkillIds.TRAIL_MEMORY,
                                "Память маршрута",
                                "Откройте навык «Память маршрута», чтобы восстановить забытый путь обсерватории."
                        )
                )
        );
    }

    private List<ExpeditionEventChoiceDefinition> memoryConstellationChoices(
            StarterInventoryContent inventoryContent
    ) {
        return List.of(
                new ExpeditionEventChoiceDefinition(
                        ARCHIVE_RETURN_PATH_CHOICE_ID,
                        "Сохранить путь возвращения",
                        "Закрепить восстановленные шаги в общей карте экспедиции.",
                        "Память стала картой",
                        "Пилот сохранил маршрут между забытыми маяками и собрал ионный свет с его опорных точек.",
                        120,
                        58,
                        reward(
                                inventoryContent,
                                StarterInventoryContent.ION_BLOOM_ID,
                                4
                        )
                ),
                new ExpeditionEventChoiceDefinition(
                        ENTRUST_MEMORY_TO_PET_CHOICE_ID,
                        "Доверить память питомцу",
                        "Позволить питомцу удержать живой ритм пути вместо неподвижной карты.",
                        "Живой проводник",
                        "Питомец запомнил дорогу как песню движения и сохранил её в шести нитях эха.",
                        92,
                        82,
                        reward(
                                inventoryContent,
                                StarterInventoryContent.ECHO_THREAD_ID,
                                6
                        )
                ),
                new ExpeditionEventChoiceDefinition(
                        STABILIZE_DAWN_CURRENT_CHOICE_ID,
                        "Стабилизировать поток рассвета",
                        "Применить Дисциплину энергии и выровнять импульсы созвездия в новый меридиан.",
                        "Рассвет обрёл ритм",
                        "Пилот распределил избыток света между опорными точками и открыл меридиан, отвечающий на ровный расход энергии.",
                        112,
                        70,
                        reward(
                                inventoryContent,
                                StarterInventoryContent.ION_BLOOM_ID,
                                3
                        ),
                        new ExpeditionChoiceSkillRequirement(
                                PlatformSkillIds.ENERGY_DISCIPLINE,
                                "Дисциплина энергии",
                                "Откройте навык «Дисциплина энергии», чтобы стабилизировать поток рассвета."
                        )
                )
        );
    }

    private List<ExpeditionEventChoiceDefinition> dawnMeridianChoices(
            StarterInventoryContent inventoryContent
    ) {
        return List.of(
                new ExpeditionEventChoiceDefinition(
                        ANCHOR_DAWN_FLOW_CHOICE_ID,
                        "Закрепить поток в маяках",
                        "Распределить рассветный импульс между опорными точками маршрута.",
                        "Меридиан стал картой",
                        "Пилот закрепил поток в сети маяков и собрал пять устойчивых фрагментов рассвета.",
                        132,
                        64,
                        reward(
                                inventoryContent,
                                StarterInventoryContent.DAWN_FRAGMENT_ID,
                                5
                        )
                ),
                new ExpeditionEventChoiceDefinition(
                        SHARE_DAWN_FLOW_WITH_PET_CHOICE_ID,
                        "Разделить поток с питомцем",
                        "Доверить питомцу удержать живой ритм меридиана в движении.",
                        "Общий ритм",
                        "Питомец принял поток, связал его с шагами отряда и сохранил семь нитей эха.",
                        100,
                        90,
                        reward(
                                inventoryContent,
                                StarterInventoryContent.ECHO_THREAD_ID,
                                7
                        )
                ),
                new ExpeditionEventChoiceDefinition(
                        CROSS_FIRST_LIGHT_CAUSEWAY_CHOICE_ID,
                        "Перейти по первому свету",
                        "Применить Ровный шаг и удержать ритм подвижного перехода над меридианом.",
                        "Свет выдержал шаг",
                        "Пилот удержал равномерный темп, провёл отряд по первому свету и собрал четыре порции призматической пыли.",
                        118,
                        76,
                        reward(
                                inventoryContent,
                                StarterInventoryContent.PRISM_DUST_ID,
                                4
                        ),
                        new ExpeditionChoiceSkillRequirement(
                                PlatformSkillIds.STEADY_STEP,
                                "Ровный шаг",
                                "Откройте навык «Ровный шаг», чтобы перейти по первому свету."
                        )
                )
        );
    }

    private List<ExpeditionEventChoiceDefinition> firstLightCausewayChoices(
            StarterInventoryContent inventoryContent
    ) {
        return List.of(
                new ExpeditionEventChoiceDefinition(
                        MAP_FIRST_LIGHT_PULSE_CHOICE_ID,
                        "Нанести импульс на карту",
                        "Закрепить точный ритм перехода в навигационной карте экспедиции.",
                        "Карта первого света",
                        "Пилот сохранил устойчивый рисунок перехода и собрал шесть ионных цветов с его опорных точек.",
                        144,
                        72,
                        reward(
                                inventoryContent,
                                StarterInventoryContent.ION_BLOOM_ID,
                                6
                        )
                ),
                new ExpeditionEventChoiceDefinition(
                        FOLLOW_PETS_STEADY_PACE_CHOICE_ID,
                        "Следовать ровному темпу питомца",
                        "Позволить питомцу провести отряд по живому ритму первого света.",
                        "Проводник рассвета",
                        "Питомец удержал переход движением и сохранил восемь нитей эха для будущего пути.",
                        110,
                        100,
                        reward(
                                inventoryContent,
                                StarterInventoryContent.ECHO_THREAD_ID,
                                8
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
