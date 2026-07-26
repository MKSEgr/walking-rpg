package com.walkingrpg.backend.progression.application;

import com.walkingrpg.backend.progression.domain.PetDefinition;
import com.walkingrpg.backend.progression.domain.PilotDefinition;
import org.springframework.stereotype.Component;

@Component
public class StarterProgressionContent {

    public static final String PILOT_ID = "navigator-v1";
    public static final String PET_ID = "spark-v1";

    private final PilotDefinition pilot = new PilotDefinition(
            PILOT_ID,
            "Навигатор",
            1,
            20,
            100,
            "Не выбрана"
    );

    private final PetDefinition pet = new PetDefinition(
            PET_ID,
            "Искра",
            "Люмин",
            1,
            10,
            "Чуткий разведчик"
    );

    public PilotDefinition pilot() {
        return pilot;
    }

    public PetDefinition pet() {
        return pet;
    }
}
