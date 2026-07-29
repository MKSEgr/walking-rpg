package com.walkingrpg.backend.progression.application;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

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

    private final Map<String, PetDefinition> pets = indexPets(List.of(
            new PetDefinition(
                    PET_ID,
                    "Искра",
                    "Люмин",
                    1,
                    10,
                    "Чуткий разведчик"
            ),
            new PetDefinition(
                    "moss-v1",
                    "Мох",
                    "Терра",
                    1,
                    10,
                    "Спокойный хранитель"
            ),
            new PetDefinition(
                    "rune-v1",
                    "Руна",
                    "Эхо",
                    1,
                    10,
                    "Смелый навигатор"
            )
    ));

    public PilotDefinition pilot() {
        return pilot;
    }

    public PetDefinition pet() {
        return requirePet(PET_ID);
    }

    public List<PetDefinition> pets() {
        return List.copyOf(pets.values());
    }

    public PetDefinition requirePet(String petId) {
        PetDefinition pet = pets.get(petId);
        if (pet == null) {
            throw new IllegalArgumentException("Неизвестный petId: " + petId);
        }
        return pet;
    }

    public boolean containsPet(String petId) {
        return pets.containsKey(petId);
    }

    private static Map<String, PetDefinition> indexPets(List<PetDefinition> definitions) {
        Map<String, PetDefinition> result = new LinkedHashMap<>();
        for (PetDefinition definition : definitions) {
            if (result.put(definition.petId(), definition) != null) {
                throw new IllegalArgumentException(
                        "Дублирующий petId: " + definition.petId()
                );
            }
        }
        return Map.copyOf(result);
    }
}
