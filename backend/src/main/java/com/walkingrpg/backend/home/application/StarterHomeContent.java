package com.walkingrpg.backend.home.application;

import com.walkingrpg.backend.home.domain.ExpeditionSnapshot;
import com.walkingrpg.backend.home.domain.PetSnapshot;
import com.walkingrpg.backend.home.domain.PilotSnapshot;
import org.springframework.stereotype.Component;

@Component
public class StarterHomeContent {

    static final String CONTENT_VERSION = "starter-v1";
    static final long DAILY_GOAL = 6_000;

    private final PilotSnapshot pilot = new PilotSnapshot(
            "Навигатор",
            1,
            20,
            100,
            "Не выбрана"
    );

    private final PetSnapshot pet = new PetSnapshot(
            "Искра",
            "Люмин",
            1,
            10,
            "Чуткий разведчик"
    );

    private final ExpeditionSnapshot expedition = new ExpeditionSnapshot(
            "Сигнал из туманного сектора",
            "Внешний маяк",
            0,
            30
    );

    public String contentVersion() {
        return CONTENT_VERSION;
    }

    public long dailyGoal() {
        return DAILY_GOAL;
    }

    public PilotSnapshot pilot() {
        return pilot;
    }

    public PetSnapshot pet() {
        return pet;
    }

    public ExpeditionSnapshot expedition() {
        return expedition;
    }
}
