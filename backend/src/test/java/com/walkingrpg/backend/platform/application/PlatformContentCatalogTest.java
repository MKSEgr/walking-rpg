package com.walkingrpg.backend.platform.application;

import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import com.walkingrpg.backend.expedition.application.StarterExpeditionContent;
import com.walkingrpg.backend.progression.application.StarterProgressionContent;
import com.walkingrpg.backend.progression.domain.PetDefinition;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class PlatformContentCatalogTest {

    private final PlatformContentCatalog catalog = new PlatformContentCatalog();

    @Test
    void shouldExposeCompleteVersionedChapterCatalog() {
        Map<String, Object> publicCatalog = publicCatalog(
                StarterExpeditionContent.CONTENT_VERSION
        );

        assertEquals("chapter-1-v2", publicCatalog.get("contentVersion"));
        assertEquals(19, publicCatalog.get("chapterNodes"));
        assertEquals(3, catalog.pets().size());
        assertEquals(4, catalog.skills().size());
        assertEquals(5, catalog.quests().size());
        assertEquals(4, catalog.cosmetics().size());
        assertEquals(2, catalog.experiments().size());
        assertEquals(6, catalog.onboardingSteps().size());
        assertEquals(8, list(publicCatalog, "achievements").size());
        assertEquals(6, list(publicCatalog, "materials").size());
        assertEquals(10, map(publicCatalog.get("season")).get("levels"));
        assertEquals(100, map(publicCatalog.get("season")).get("xpPerLevel"));
        assertEquals(300, catalog.requiredSeasonXpForRewardLevel(3));
        assertEquals(3, catalog.seasonLevelForXp(220));
        assertEquals(64, String.valueOf(publicCatalog.get("catalogDigest")).length());
    }

    @Test
    void shouldExposeStormRiftNodeOnlyInChapterV3Catalog() {
        Map<String, Object> stormRiftCatalog = publicCatalog(
                StarterExpeditionContent.STORM_RIFT_CONTENT_VERSION
        );
        Map<String, Object> resonanceCatalog = publicCatalog(
                StarterExpeditionContent.CONTENT_VERSION
        );

        assertEquals("chapter-1-v3", stormRiftCatalog.get("contentVersion"));
        assertEquals(20, stormRiftCatalog.get("chapterNodes"));
        assertEquals(19, resonanceCatalog.get("chapterNodes"));
        assertNotEquals(
                stormRiftCatalog.get("catalogDigest"),
                resonanceCatalog.get("catalogDigest")
        );
    }

    @Test
    void shouldExposeVoidOrchardForkOnlyInChapterV4Catalog() {
        Map<String, Object> voidOrchardCatalog = publicCatalog(
                StarterExpeditionContent.VOID_ORCHARD_CONTENT_VERSION
        );
        Map<String, Object> stormRiftCatalog = publicCatalog(
                StarterExpeditionContent.STORM_RIFT_CONTENT_VERSION
        );

        assertEquals("chapter-1-v4", voidOrchardCatalog.get("contentVersion"));
        assertEquals(22, voidOrchardCatalog.get("chapterNodes"));
        assertEquals(20, stormRiftCatalog.get("chapterNodes"));
        assertNotEquals(
                voidOrchardCatalog.get("catalogDigest"),
                stormRiftCatalog.get("catalogDigest")
        );
    }

    @Test
    void shouldExposePrismSextantRouteOnlyInChapterV5Catalog() {
        Map<String, Object> prismCatalog = publicCatalog(
                StarterExpeditionContent.PRISM_SEXTANT_CONTENT_VERSION
        );
        Map<String, Object> voidOrchardCatalog = publicCatalog(
                StarterExpeditionContent.VOID_ORCHARD_CONTENT_VERSION
        );

        assertEquals("chapter-1-v5", prismCatalog.get("contentVersion"));
        assertEquals(23, prismCatalog.get("chapterNodes"));
        assertEquals(22, voidOrchardCatalog.get("chapterNodes"));
        assertNotEquals(
                prismCatalog.get("catalogDigest"),
                voidOrchardCatalog.get("catalogDigest")
        );
    }

    @Test
    void shouldExposeCalibratedChoiceVersionWithSameChapterTopology() {
        Map<String, Object> calibratedCatalog = publicCatalog(
                StarterExpeditionContent.CALIBRATED_SEXTANT_CONTENT_VERSION
        );
        Map<String, Object> prismCatalog = publicCatalog(
                StarterExpeditionContent.PRISM_SEXTANT_CONTENT_VERSION
        );

        assertEquals("chapter-1-v6", calibratedCatalog.get("contentVersion"));
        assertEquals(23, calibratedCatalog.get("chapterNodes"));
        assertEquals(23, prismCatalog.get("chapterNodes"));
        assertNotEquals(
                calibratedCatalog.get("catalogDigest"),
                prismCatalog.get("catalogDigest")
        );
    }

    @Test
    void shouldExposeSecondDawnEpilogueOnlyInChapterV7Catalog() {
        Map<String, Object> secondDawnCatalog = publicCatalog(
                StarterExpeditionContent.SECOND_DAWN_CONTENT_VERSION
        );
        Map<String, Object> calibratedCatalog = publicCatalog(
                StarterExpeditionContent.CALIBRATED_SEXTANT_CONTENT_VERSION
        );

        assertEquals("chapter-1-v7", secondDawnCatalog.get("contentVersion"));
        assertEquals(24, secondDawnCatalog.get("chapterNodes"));
        assertEquals(23, calibratedCatalog.get("chapterNodes"));
        assertNotEquals(
                secondDawnCatalog.get("catalogDigest"),
                calibratedCatalog.get("catalogDigest")
        );
    }

    @Test
    void shouldKeepSecondDawnTopologyForAttunementRelease() {
        Map<String, Object> attunementCatalog = publicCatalog(
                StarterExpeditionContent
                        .SECOND_DAWN_ATTUNEMENT_CONTENT_VERSION
        );
        Map<String, Object> secondDawnCatalog = publicCatalog(
                StarterExpeditionContent.SECOND_DAWN_CONTENT_VERSION
        );

        assertEquals("chapter-1-v8", attunementCatalog.get("contentVersion"));
        assertEquals(24, attunementCatalog.get("chapterNodes"));
        assertEquals(24, secondDawnCatalog.get("chapterNodes"));
        assertNotEquals(
                attunementCatalog.get("catalogDigest"),
                secondDawnCatalog.get("catalogDigest")
        );
    }

    @Test
    void shouldExposeUnchartedVergeOnlyInChapterV9Catalog() {
        Map<String, Object> unchartedCatalog = publicCatalog(
                StarterExpeditionContent.UNCHARTED_VERGE_CONTENT_VERSION
        );
        Map<String, Object> attunementCatalog = publicCatalog(
                StarterExpeditionContent
                        .SECOND_DAWN_ATTUNEMENT_CONTENT_VERSION
        );

        assertEquals("chapter-1-v9", unchartedCatalog.get("contentVersion"));
        assertEquals(25, unchartedCatalog.get("chapterNodes"));
        assertEquals(24, attunementCatalog.get("chapterNodes"));
        assertNotEquals(
                unchartedCatalog.get("catalogDigest"),
                attunementCatalog.get("catalogDigest")
        );
    }

    @Test
    void shouldKeepUnchartedTopologyForPetGuidedRelease() {
        Map<String, Object> petGuidedCatalog = publicCatalog(
                StarterExpeditionContent
                        .PET_GUIDED_UNCHARTED_CONTENT_VERSION
        );
        Map<String, Object> unchartedCatalog = publicCatalog(
                StarterExpeditionContent.UNCHARTED_VERGE_CONTENT_VERSION
        );

        assertEquals("chapter-1-v10", petGuidedCatalog.get("contentVersion"));
        assertEquals(25, petGuidedCatalog.get("chapterNodes"));
        assertEquals(25, unchartedCatalog.get("chapterNodes"));
        assertNotEquals(
                petGuidedCatalog.get("catalogDigest"),
                unchartedCatalog.get("catalogDigest")
        );
    }

    @Test
    void shouldExposeAdultPetFormsOnlyInChapterV11Catalog() {
        Map<String, Object> adultCatalog = publicCatalog(
                StarterExpeditionContent.ADULT_PET_EVOLUTION_CONTENT_VERSION
        );
        Map<String, Object> petGuidedCatalog = publicCatalog(
                StarterExpeditionContent.PET_GUIDED_UNCHARTED_CONTENT_VERSION
        );

        Map<String, Object> adultSpark = map(list(adultCatalog, "pets").getFirst());
        Map<String, Object> legacySpark = map(
                list(petGuidedCatalog, "pets").getFirst()
        );

        assertEquals("chapter-1-v11", adultCatalog.get("contentVersion"));
        assertEquals(25, adultCatalog.get("chapterNodes"));
        assertEquals(25, petGuidedCatalog.get("chapterNodes"));
        assertEquals("Искра-звездочёт", adultSpark.get("adultName"));
        assertEquals(140, adultSpark.get("adultEvolutionBond"));
        assertEquals(2, adultSpark.get("maximumEvolutionStage"));
        assertEquals(
                List.of(
                        "Искра-звездочёт:140",
                        "Мох-оплот:125",
                        "Навигатор созвездий:150"
                ),
                list(adultCatalog, "pets").stream()
                        .map(PlatformContentCatalogTest::map)
                        .map(pet -> pet.get("adultName") + ":"
                                + pet.get("adultEvolutionBond"))
                        .toList()
        );
        assertFalse(legacySpark.containsKey("adultName"));
        assertFalse(legacySpark.containsKey("adultEvolutionBond"));
        assertFalse(legacySpark.containsKey("maximumEvolutionStage"));
        assertNotEquals(
                adultCatalog.get("catalogDigest"),
                petGuidedCatalog.get("catalogDigest")
        );
    }

    @Test
    void shouldExposeAdultPetFrontierNodeOnlyInChapterV12Catalog() {
        Map<String, Object> frontierCatalog = publicCatalog(
                StarterExpeditionContent.ADULT_PET_FRONTIER_CONTENT_VERSION
        );
        Map<String, Object> adultCatalog = publicCatalog(
                StarterExpeditionContent.ADULT_PET_EVOLUTION_CONTENT_VERSION
        );

        assertEquals("chapter-1-v12", frontierCatalog.get("contentVersion"));
        assertEquals(26, frontierCatalog.get("chapterNodes"));
        assertEquals(25, adultCatalog.get("chapterNodes"));
        assertEquals(
                list(adultCatalog, "pets"),
                list(frontierCatalog, "pets")
        );
        assertNotEquals(
                adultCatalog.get("catalogDigest"),
                frontierCatalog.get("catalogDigest")
        );
    }

    @Test
    void shouldKeepAdultFrontierTopologyForPilotSkillRelease() {
        Map<String, Object> skillCatalog = publicCatalog(
                StarterExpeditionContent.PILOT_SKILL_CHOICE_CONTENT_VERSION
        );
        Map<String, Object> frontierCatalog = publicCatalog(
                StarterExpeditionContent.ADULT_PET_FRONTIER_CONTENT_VERSION
        );

        assertEquals("chapter-1-v13", skillCatalog.get("contentVersion"));
        assertEquals(26, skillCatalog.get("chapterNodes"));
        assertEquals(26, frontierCatalog.get("chapterNodes"));
        assertEquals(
                list(frontierCatalog, "skills"),
                list(skillCatalog, "skills")
        );
        assertNotEquals(
                frontierCatalog.get("catalogDigest"),
                skillCatalog.get("catalogDigest")
        );
    }

    @Test
    void shouldExposeSecretSignalRouteOnlyInChapterV14Catalog() {
        Map<String, Object> secretRouteCatalog = publicCatalog(
                StarterExpeditionContent
                        .SIGNAL_READER_SECRET_ROUTE_CONTENT_VERSION
        );
        Map<String, Object> skillCatalog = publicCatalog(
                StarterExpeditionContent.PILOT_SKILL_CHOICE_CONTENT_VERSION
        );

        assertEquals("chapter-1-v14",
                secretRouteCatalog.get("contentVersion"));
        assertEquals(27, secretRouteCatalog.get("chapterNodes"));
        assertEquals(26, skillCatalog.get("chapterNodes"));
        assertEquals(
                list(skillCatalog, "skills"),
                list(secretRouteCatalog, "skills")
        );
        assertNotEquals(
                skillCatalog.get("catalogDigest"),
                secretRouteCatalog.get("catalogDigest")
        );
    }

    @Test
    void shouldExposeTrailMemoryRouteOnlyInChapterV15Catalog() {
        Map<String, Object> trailMemoryCatalog = publicCatalog(
                StarterExpeditionContent.TRAIL_MEMORY_ROUTE_CONTENT_VERSION
        );
        Map<String, Object> secretRouteCatalog = publicCatalog(
                StarterExpeditionContent
                        .SIGNAL_READER_SECRET_ROUTE_CONTENT_VERSION
        );

        assertEquals("chapter-1-v15",
                trailMemoryCatalog.get("contentVersion"));
        assertEquals(28, trailMemoryCatalog.get("chapterNodes"));
        assertEquals(27, secretRouteCatalog.get("chapterNodes"));
        assertEquals(
                list(secretRouteCatalog, "skills"),
                list(trailMemoryCatalog, "skills")
        );
        assertNotEquals(
                secretRouteCatalog.get("catalogDigest"),
                trailMemoryCatalog.get("catalogDigest")
        );
    }

    @Test
    void shouldExposeEnergyDisciplineRouteOnlyInChapterV16Catalog() {
        Map<String, Object> energyDisciplineCatalog = publicCatalog(
                StarterExpeditionContent
                        .ENERGY_DISCIPLINE_ROUTE_CONTENT_VERSION
        );
        Map<String, Object> trailMemoryCatalog = publicCatalog(
                StarterExpeditionContent.TRAIL_MEMORY_ROUTE_CONTENT_VERSION
        );

        assertEquals("chapter-1-v16",
                energyDisciplineCatalog.get("contentVersion"));
        assertEquals(29, energyDisciplineCatalog.get("chapterNodes"));
        assertEquals(28, trailMemoryCatalog.get("chapterNodes"));
        assertEquals(
                list(trailMemoryCatalog, "skills"),
                list(energyDisciplineCatalog, "skills")
        );
        assertNotEquals(
                trailMemoryCatalog.get("catalogDigest"),
                energyDisciplineCatalog.get("catalogDigest")
        );
    }

    @Test
    void shouldExposeSteadyStepRouteOnlyInChapterV17Catalog() {
        Map<String, Object> steadyStepCatalog = publicCatalog(
                StarterExpeditionContent.STEADY_STEP_ROUTE_CONTENT_VERSION
        );
        Map<String, Object> energyDisciplineCatalog = publicCatalog(
                StarterExpeditionContent
                        .ENERGY_DISCIPLINE_ROUTE_CONTENT_VERSION
        );

        assertEquals("chapter-1-v17",
                steadyStepCatalog.get("contentVersion"));
        assertEquals(30, steadyStepCatalog.get("chapterNodes"));
        assertEquals(29, energyDisciplineCatalog.get("chapterNodes"));
        assertEquals(
                list(energyDisciplineCatalog, "skills"),
                list(steadyStepCatalog, "skills")
        );
        assertNotEquals(
                energyDisciplineCatalog.get("catalogDigest"),
                steadyStepCatalog.get("catalogDigest")
        );
    }

    @Test
    void shouldKeepOptionalRouteOutOfLegacyCatalog() {
        Map<String, Object> publicCatalog = publicCatalog(
                StarterExpeditionContent.LEGACY_CONTENT_VERSION
        );

        assertEquals("chapter-1-v1", publicCatalog.get("contentVersion"));
        assertEquals(18, publicCatalog.get("chapterNodes"));
    }

    @Test
    void shouldChangeDigestWhenCatalogContentChanges() {
        Map<String, Object> current = publicCatalog(
                StarterExpeditionContent.CONTENT_VERSION
        );
        Map<String, Object> legacy = publicCatalog(
                StarterExpeditionContent.LEGACY_CONTENT_VERSION
        );

        assertNotEquals(current.get("catalogDigest"), legacy.get("catalogDigest"));
        assertEquals(
                current.get("catalogDigest"),
                new PlatformContentCatalog()
                        .publicCatalog(
                                StarterExpeditionContent.CONTENT_VERSION,
                                "season-1",
                                120
                        )
                        .get("catalogDigest")
        );
    }

    @Test
    void shouldIncludeRuntimeCatalogValuesInProjectionAndDigest() {
        Map<String, Object> configured = catalog.publicCatalog(
                StarterExpeditionContent.CONTENT_VERSION,
                "signal-season-2",
                175
        );
        Map<String, Object> changedSeason = catalog.publicCatalog(
                StarterExpeditionContent.CONTENT_VERSION,
                "signal-season-3",
                175
        );
        Map<String, Object> changedEnergy = catalog.publicCatalog(
                StarterExpeditionContent.CONTENT_VERSION,
                "signal-season-2",
                180
        );

        assertEquals("signal-season-2", map(configured.get("season")).get("seasonId"));
        assertEquals(175, map(configured.get("weeklyRoute")).get("requiredEnergy"));
        assertNotEquals(
                configured.get("catalogDigest"),
                changedSeason.get("catalogDigest")
        );
        assertNotEquals(
                configured.get("catalogDigest"),
                changedEnergy.get("catalogDigest")
        );
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
    void shouldExposeCanonicalNavigatorCopyBehindStablePetId() {
        PlatformContentCatalog.PetDefinition platformPet =
                catalog.requirePet(StarterProgressionContent.RUNE_PET_ID);
        PetDefinition gameplayPet = new StarterProgressionContent()
                .requirePet(StarterProgressionContent.RUNE_PET_ID);

        assertEquals("rune-v1", platformPet.petId());
        assertEquals("Навигатор", platformPet.name());
        assertEquals("Навигатор потоков", platformPet.evolvedName());
        assertEquals("Навигатор созвездий", platformPet.adultName());
        assertEquals("Точный проводник", platformPet.trait());
        assertEquals("Навигатор", gameplayPet.name());
        assertEquals("Точный проводник", gameplayPet.trait());
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
    void shouldKeepEveryCosmeticInAPersistentServerOwnedSlot() {
        Set<String> supportedSlots = Set.of("PILOT", "PET", "PROFILE");

        assertTrue(catalog.cosmetics().stream()
                .map(PlatformContentCatalog.CosmeticDefinition::slot)
                .allMatch(supportedSlots::contains));
        assertEquals(
                supportedSlots,
                new HashSet<>(catalog.cosmetics().stream()
                        .map(PlatformContentCatalog.CosmeticDefinition::slot)
                        .toList())
        );
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

    private Map<String, Object> publicCatalog(String contentVersion) {
        return catalog.publicCatalog(contentVersion, "season-1", 120);
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> map(Object value) {
        return (Map<String, Object>) value;
    }
}
