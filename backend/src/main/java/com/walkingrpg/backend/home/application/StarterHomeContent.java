package com.walkingrpg.backend.home.application;

import com.walkingrpg.backend.home.domain.PetSnapshot;
import com.walkingrpg.backend.home.domain.PilotSnapshot;
import com.walkingrpg.backend.progression.application.StarterProgressionContent;
import com.walkingrpg.backend.progression.domain.PetDefinition;
import com.walkingrpg.backend.progression.domain.PilotDefinition;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

@Component
public class StarterHomeContent {

    static final String CONTENT_VERSION = "starter-v1";
    private final StarterProgressionContent progressionContent;

    public StarterHomeContent() {
        this(new StarterProgressionContent());
    }

    @Autowired
    public StarterHomeContent(StarterProgressionContent progressionContent) {
        this.progressionContent = progressionContent;
    }

    public String contentVersion() {
        return CONTENT_VERSION;
    }

    public PilotSnapshot pilot() {
        PilotDefinition pilot = progressionContent.pilot();
        return new PilotSnapshot(
                pilot.name(),
                pilot.initialLevel(),
                pilot.initialExperience(),
                pilot.nextLevelExperience(),
                pilot.specialization()
        );
    }

    public PetSnapshot pet() {
        PetDefinition pet = progressionContent.pet();
        return new PetSnapshot(
                pet.name(),
                pet.species(),
                pet.initialLevel(),
                pet.initialBond(),
                pet.trait()
        );
    }
}
