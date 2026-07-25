package com.walkingrpg.backend.expedition.application;

import com.walkingrpg.backend.expedition.domain.ExpeditionDefinition;
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

    public ExpeditionDefinition require(String expeditionId) {
        if (!EXPEDITION_ID.equals(expeditionId)) {
            throw new ExpeditionNotFoundException(expeditionId);
        }
        return definition;
    }

    public ExpeditionDefinition definition() {
        return definition;
    }
}
