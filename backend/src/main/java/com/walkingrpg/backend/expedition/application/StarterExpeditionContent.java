package com.walkingrpg.backend.expedition.application;

import java.util.List;

import com.walkingrpg.backend.expedition.domain.ExpeditionDefinition;
import com.walkingrpg.backend.expedition.domain.ExpeditionEventChoiceDefinition;
import com.walkingrpg.backend.expedition.domain.ExpeditionEventDefinition;
import org.springframework.stereotype.Component;

@Component
public class StarterExpeditionContent {

    public static final String CONTENT_VERSION = "starter-v1";
    public static final String EXPEDITION_ID = "starter-expedition-v1";
    public static final String EVENT_ID = "signal-source-v1";

    private final ExpeditionDefinition definition = new ExpeditionDefinition(
            CONTENT_VERSION,
            EXPEDITION_ID,
            "Сигнал из туманного сектора",
            "outer-beacon",
            "Внешний маяк",
            30,
            new ExpeditionEventDefinition(
                    EVENT_ID,
                    "Источник сигнала",
                    "Маяк отвечает повторяющимся импульсом. Нужно решить, как войти внутрь."
            )
    );

    private final List<ExpeditionEventChoiceDefinition> choices = List.of(
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

    public ExpeditionDefinition require(String expeditionId) {
        if (!EXPEDITION_ID.equals(expeditionId)) {
            throw new ExpeditionNotFoundException(expeditionId);
        }
        return definition;
    }

    public ExpeditionDefinition requireEvent(String eventId) {
        if (!EVENT_ID.equals(eventId)) {
            throw new EventNotFoundException(eventId);
        }
        return definition;
    }

    public ExpeditionEventChoiceDefinition requireChoice(
            String eventId,
            String choiceId
    ) {
        requireEvent(eventId);
        return choices.stream()
                .filter(choice -> choice.choiceId().equals(choiceId))
                .findFirst()
                .orElseThrow(() -> new EventResolutionValidationException(
                        "Неизвестный choiceId для события " + eventId,
                        "choiceId"
                ));
    }

    public List<ExpeditionEventChoiceDefinition> eventChoices(String eventId) {
        requireEvent(eventId);
        return choices;
    }

    public ExpeditionDefinition definition() {
        return definition;
    }
}
