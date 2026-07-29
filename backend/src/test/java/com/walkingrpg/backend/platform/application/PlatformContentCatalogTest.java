package com.walkingrpg.backend.platform.application;

import java.util.HashSet;
import java.util.List;
import java.util.Map;

import com.walkingrpg.backend.progression.application.StarterProgressionContent;
import com.walkingrpg.backend.progression.domain.PetDefinition;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class PlatformContentCatalogTest {

    private final PlatformContentCatalog catalog = new PlatformContentCatalog();

    @Test
    void shouldExposeCompleteVersionedChapterCatalog() {
        Map<String, Object> publicCatalog = catalog.publicCatalog();

        assertEquals("chapter-1-v1", publicCatalog.get("contentVersion"));
        assertEquals(18, publicCatalog.get("chapterNodes"));
        assertEquals(3, catalog.pets().size());
        assertEquals(4, catalog.skills().size());
        assertEquals(5, catalog.quests().size());
        assertEquals(4, catalog.cosmetics().size());
        assertEquals(2, catalog.experiments().size());
        assertEquals(6, catalog.onboardingSteps().size());
        assertEquals(6, list(publicCatalog, "materials").size());
        assertEquals(64, String.valueOf(publicCatalog.get("catalogDigest")).length());
    }

    @Test
    void shouldKeepPlatformAndGameplayPetDefinitionsAligned() {
        StarterProgressionContent progression = new StarterProgressionContent();

        for (PlatformContentCatalog.PetDefinition platformPet : catalog.pets()) {
            PetDefinition gameplayPet = progression.requirePet(platformPet.petId());
            assertEquals(platformPet.name(), gameplayPet.name());
            assertTrue(platformPet.species().equalsIgnoreCase(gameplayPet.species()));
            assertEquals(platformPet.trait(), gameplayPet.trait());
            assertEquals(platformPet.initialBond(), gameplayPet.initialBond());
        }
    }

    @Test
    void shouldKeepContentIdentifiersUnique() {
        assertEquals(catalog.pets().size(), new HashSet<>(catalog.pets().stream()
                .map(PlatformContentCatalog.PetDefinition::petId)
                .toList()).size());
        assertEquals(catalog.skills().size(), new HashSet<>(catalog.skills().stream()
                .map(PlatformContentCatalog.SkillDefinition::skillId)
                .toList()).size());
        assertEquals(catalog.quests().size(), new HashSet<>(catalog.quests().stream()
                .map(PlatformContentCatalog.QuestDefinition::questId)
                .toList()).size());
        assertEquals(catalog.cosmetics().size(), new HashSet<>(catalog.cosmetics().stream()
                .map(PlatformContentCatalog.CosmeticDefinition::cosmeticId)
                .toList()).size());
    }

    @Test
    void shouldAssignStableSupportedExperimentVariant() {
        PlatformContentCatalog.ExperimentDefinition experiment =
                catalog.experiments().getFirst();

        String first = catalog.variantFor("stable-user", experiment);
        String second = catalog.variantFor("stable-user", experiment);

        assertEquals(first, second);
        assertTrue(experiment.variants().contains(first));
    }

    @Test
    void shouldRejectUnknownContentIdentifiers() {
        assertThrows(PlatformValidationException.class, () -> catalog.requirePet("missing"));
        assertThrows(PlatformValidationException.class, () -> catalog.requireSkill("missing"));
        assertThrows(PlatformValidationException.class, () -> catalog.requireQuest("missing"));
        assertThrows(PlatformValidationException.class, () -> catalog.requireCosmetic("missing"));
    }

    @SuppressWarnings("unchecked")
    private static List<Object> list(Map<String, Object> map, String key) {
        return (List<Object>) map.get(key);
    }
}
