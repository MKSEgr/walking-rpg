package com.walkingrpg.backend.expedition.application;

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

    public static final String CONTENT_VERSION = "starter-v2";
    public static final String EXPEDITION_ID = "starter-expedition-v1";

    public static final String FIRST_NODE_ID = "outer-beacon";
    public static final String FIRST_EVENT_ID = "signal-source-v1";
    /** Backward-compatible alias used by the first playable tests and clients. */
    public static final String EVENT_ID = FIRST_EVENT_ID;

    public static final String SECOND_NODE_ID = "lumen-gate";
    public static final String SECOND_EVENT_ID = "echo-vault-v1";

    private final ExpeditionDefinition firstNode;
    private final ExpeditionDefinition secondNode;
    private final Map<String, ExpeditionDefinition> nodeById;
    private final Map<String, ExpeditionDefinition> nodeByEventId;
    private final Map<String, List<ExpeditionEventChoiceDefinition>> choicesByEventId;

    public StarterExpeditionContent() {
        this(new StarterInventoryContent());
    }

    @Autowired
    public StarterExpeditionContent(StarterInventoryContent inventoryContent) {
        this.firstNode = new ExpeditionDefinition(
                CONTENT_VERSION,
                EXPEDITION_ID,
                "Сигнал из туманного сектора",
                FIRST_NODE_ID,
                "Внешний маяк",
                30,
                new ExpeditionEventDefinition(
                        FIRST_EVENT_ID,
                        "Источник сигнала",
                        "Маяк отвечает повторяющимся импульсом. Нужно решить, как войти внутрь."
                )
        );
        this.secondNode = new ExpeditionDefinition(
                CONTENT_VERSION,
                EXPEDITION_ID,
                "Сигнал из туманного сектора",
                SECOND_NODE_ID,
                "Люминовые ворота",
                45,
                new ExpeditionEventDefinition(
                        SECOND_EVENT_ID,
                        "Хранилище эха",
                        "За воротами найден архив маршрутов. Его ядро нестабильно, а Искра слышит зов из глубины."
                )
        );
        this.nodeById = Map.of(
                firstNode.currentNodeId(), firstNode,
                secondNode.currentNodeId(), secondNode
        );
        this.nodeByEventId = Map.of(
                firstNode.event().eventId(), firstNode,
                secondNode.event().eventId(), secondNode
        );
        this.choicesByEventId = Map.of(
                FIRST_EVENT_ID,
                List.of(
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
                ),
                SECOND_EVENT_ID,
                List.of(
                        new ExpeditionEventChoiceDefinition(
                                "stabilize-core",
                                "Стабилизировать ядро",
                                "Навигатор зафиксирует резонанс и извлечёт безопасные фрагменты.",
                                "Стабильный резонанс",
                                "Ядро перестало разрушаться, а два люминовых осколка сохранили его энергию.",
                                30,
                                8,
                                new InventoryRewardDefinition(
                                        inventoryContent.require(
                                                StarterInventoryContent.LUMEN_SHARD_ID
                                        ),
                                        2
                                )
                        ),
                        new ExpeditionEventChoiceDefinition(
                                "follow-echo",
                                "Последовать за эхом",
                                "Искра проведёт отряд по живому следу в глубине архива.",
                                "Нить маршрута",
                                "Искра нашла безопасный путь и вынесла нить эха, сохранившую его структуру.",
                                20,
                                18,
                                new InventoryRewardDefinition(
                                        inventoryContent.require(
                                                StarterInventoryContent.ECHO_THREAD_ID
                                        ),
                                        1
                                )
                        )
                )
        );
    }

    public ExpeditionDefinition require(String expeditionId) {
        if (!EXPEDITION_ID.equals(expeditionId)) {
            throw new ExpeditionNotFoundException(expeditionId);
        }
        return firstNode;
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
        return FIRST_EVENT_ID.equals(eventId)
                ? Optional.of(secondNode)
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
        return firstNode;
    }

    public ExpeditionDefinition initialDefinition() {
        return firstNode;
    }

    public String contentVersion() {
        return CONTENT_VERSION;
    }
}
