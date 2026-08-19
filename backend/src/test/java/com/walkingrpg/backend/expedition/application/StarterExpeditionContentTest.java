package com.walkingrpg.backend.expedition.application;

import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;

import com.walkingrpg.backend.expedition.domain.ExpeditionEventChoiceDefinition;
import com.walkingrpg.backend.platform.domain.PlatformSkillIds;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class StarterExpeditionContentTest {

    private final StarterExpeditionContent content = new StarterExpeditionContent();

    @Test
    void shouldExposeCanonicalNavigatorCopyForStableRuneRoutes() {
        ExpeditionEventChoiceDefinition guidedChoice = content.requireChoice(
                StarterExpeditionContent.UNCHARTED_VERGE_EVENT_ID,
                StarterExpeditionContent.RUNE_UNCHARTED_CHOICE_ID,
                StarterExpeditionContent.PET_GUIDED_UNCHARTED_CONTENT_VERSION
        );
        ExpeditionEventChoiceDefinition adultChoice = content.requireChoice(
                StarterExpeditionContent.UNCHARTED_VERGE_EVENT_ID,
                StarterExpeditionContent.RUNE_ADULT_FRONTIER_CHOICE_ID,
                StarterExpeditionContent.ADULT_PET_FRONTIER_CONTENT_VERSION
        );

        assertEquals("Расшифровать созвездие с Навигатором",
                guidedChoice.title());
        assertEquals("Навигатор", guidedChoice.petRequirement().petName());
        assertEquals("rune-v1", guidedChoice.petRequirement().petId());
        assertTrue(guidedChoice.outcomeSummary().startsWith("Навигатор "));
        assertFalse(guidedChoice.description().contains("Руна"));
        assertFalse(guidedChoice.petRequirement().lockedReason().contains("Руна"));

        assertEquals("Прочесть врата с Навигатором созвездий",
                adultChoice.title());
        assertEquals("Навигатор созвездий",
                adultChoice.petRequirement().petName());
        assertEquals("rune-v1", adultChoice.petRequirement().petId());
        assertEquals(2, adultChoice.petRequirement().minimumEvolutionStage());
        assertTrue(adultChoice.outcomeSummary()
                .startsWith("Навигатор созвездий "));
        assertFalse(adultChoice.description().contains("Руна"));
        assertFalse(adultChoice.petRequirement().lockedReason().contains("Руна"));
    }

    @Test
    void shouldGateOptionalRoutesByActiveContentVersion() {
        AtomicInteger activationReads = new AtomicInteger();
        String chapterV2 = content.activeContentVersion(
                () -> StarterExpeditionContent.CONTENT_VERSION
        );
        String chapterV3 = content.activeContentVersion(
                () -> StarterExpeditionContent.STORM_RIFT_CONTENT_VERSION
        );
        String chapterV4 = content.activeContentVersion(
                () -> {
                    activationReads.incrementAndGet();
                    return StarterExpeditionContent.VOID_ORCHARD_CONTENT_VERSION;
                }
        );
        String chapterV5 = content.activeContentVersion(
                () -> StarterExpeditionContent.PRISM_SEXTANT_CONTENT_VERSION
        );
        String chapterV6 = content.activeContentVersion(
                () -> StarterExpeditionContent.CALIBRATED_SEXTANT_CONTENT_VERSION
        );
        String chapterV7 = content.activeContentVersion(
                () -> StarterExpeditionContent.SECOND_DAWN_CONTENT_VERSION
        );
        String chapterV8 = content.activeContentVersion(
                () -> StarterExpeditionContent
                        .SECOND_DAWN_ATTUNEMENT_CONTENT_VERSION
        );
        String chapterV9 = content.activeContentVersion(
                () -> StarterExpeditionContent.UNCHARTED_VERGE_CONTENT_VERSION
        );
        String chapterV10 = content.activeContentVersion(
                () -> StarterExpeditionContent
                        .PET_GUIDED_UNCHARTED_CONTENT_VERSION
        );
        String chapterV11 = content.activeContentVersion(
                () -> StarterExpeditionContent
                        .ADULT_PET_EVOLUTION_CONTENT_VERSION
        );
        String chapterV12 = content.activeContentVersion(
                () -> StarterExpeditionContent
                        .ADULT_PET_FRONTIER_CONTENT_VERSION
        );
        String chapterV13 = content.activeContentVersion(
                () -> StarterExpeditionContent
                        .PILOT_SKILL_CHOICE_CONTENT_VERSION
        );
        String chapterV14 = content.activeContentVersion(
                () -> StarterExpeditionContent
                        .SIGNAL_READER_SECRET_ROUTE_CONTENT_VERSION
        );
        String chapterV15 = content.activeContentVersion(
                () -> StarterExpeditionContent
                        .TRAIL_MEMORY_ROUTE_CONTENT_VERSION
        );
        String chapterV16 = content.activeContentVersion(
                () -> StarterExpeditionContent
                        .ENERGY_DISCIPLINE_ROUTE_CONTENT_VERSION
        );
        String chapterV17 = content.activeContentVersion(
                () -> StarterExpeditionContent
                        .STEADY_STEP_ROUTE_CONTENT_VERSION
        );

        assertEquals(StarterExpeditionContent.CONTENT_VERSION, chapterV2);
        assertEquals(StarterExpeditionContent.STORM_RIFT_CONTENT_VERSION, chapterV3);
        assertEquals(StarterExpeditionContent.VOID_ORCHARD_CONTENT_VERSION, chapterV4);
        assertEquals(StarterExpeditionContent.PRISM_SEXTANT_CONTENT_VERSION,
                chapterV5);
        assertEquals(
                StarterExpeditionContent.CALIBRATED_SEXTANT_CONTENT_VERSION,
                chapterV6
        );
        assertEquals(StarterExpeditionContent.SECOND_DAWN_CONTENT_VERSION,
                chapterV7);
        assertEquals(
                StarterExpeditionContent
                        .SECOND_DAWN_ATTUNEMENT_CONTENT_VERSION,
                chapterV8
        );
        assertEquals(
                StarterExpeditionContent.UNCHARTED_VERGE_CONTENT_VERSION,
                chapterV9
        );
        assertEquals(
                StarterExpeditionContent.PET_GUIDED_UNCHARTED_CONTENT_VERSION,
                chapterV10
        );
        assertEquals(
                StarterExpeditionContent.ADULT_PET_EVOLUTION_CONTENT_VERSION,
                chapterV11
        );
        assertEquals(
                StarterExpeditionContent.ADULT_PET_FRONTIER_CONTENT_VERSION,
                chapterV12
        );
        assertEquals(
                StarterExpeditionContent.PILOT_SKILL_CHOICE_CONTENT_VERSION,
                chapterV13
        );
        assertEquals(
                StarterExpeditionContent
                        .SIGNAL_READER_SECRET_ROUTE_CONTENT_VERSION,
                chapterV14
        );
        assertEquals(
                StarterExpeditionContent.TRAIL_MEMORY_ROUTE_CONTENT_VERSION,
                chapterV15
        );
        assertEquals(
                StarterExpeditionContent
                        .ENERGY_DISCIPLINE_ROUTE_CONTENT_VERSION,
                chapterV16
        );
        assertEquals(
                StarterExpeditionContent.STEADY_STEP_ROUTE_CONTENT_VERSION,
                chapterV17
        );
        assertEquals(1, activationReads.get());
        assertEquals(
                StarterExpeditionContent.LEGACY_CONTENT_VERSION,
                content.activeContentVersion(() -> null)
        );
        assertEquals(
                StarterExpeditionContent.LEGACY_CONTENT_VERSION,
                content.activeContentVersion(() -> "chapter-2-v1")
        );
        assertFalse(hasStormRiftChoice(content.eventChoices(
                StarterExpeditionContent.STORM_ARCHIVE_EVENT_ID,
                chapterV2
        )));
        assertTrue(hasStormRiftChoice(content.eventChoices(
                StarterExpeditionContent.STORM_ARCHIVE_EVENT_ID,
                chapterV3
        )));
        assertFalse(hasVoidOrchardChoice(content.eventChoices(
                StarterExpeditionContent.VOID_ORCHARD_EVENT_ID,
                chapterV3
        )));
        assertTrue(hasVoidOrchardChoice(content.eventChoices(
                StarterExpeditionContent.VOID_ORCHARD_EVENT_ID,
                chapterV4
        )));
        assertFalse(hasPrismSextantChoice(content.eventChoices(
                StarterExpeditionContent.STAR_WELL_EVENT_ID,
                chapterV4
        )));
        assertTrue(hasPrismSextantChoice(content.eventChoices(
                StarterExpeditionContent.STAR_WELL_EVENT_ID,
                chapterV5
        )));
        assertFalse(hasCalibratedSextantChoice(content.eventChoices(
                StarterExpeditionContent.SPECTRUM_OBSERVATORY_EVENT_ID,
                chapterV5
        )));
        List<ExpeditionEventChoiceDefinition> calibratedChoices =
                content.eventChoices(
                        StarterExpeditionContent.SPECTRUM_OBSERVATORY_EVENT_ID,
                        chapterV6
                );
        assertTrue(hasCalibratedSextantChoice(calibratedChoices));
        assertEquals(
                2,
                calibratedChoices.stream()
                        .filter(choice ->
                                StarterExpeditionContent
                                        .CALIBRATED_SEXTANT_CHOICE_ID
                                        .equals(choice.choiceId()))
                        .findFirst()
                        .orElseThrow()
                        .equipmentRequirement()
                        .minimumUpgradeLevel()
        );
        assertFalse(hasSecondDawnChoice(content.eventChoices(
                StarterExpeditionContent.FINAL_EVENT_ID,
                chapterV6
        )));
        assertTrue(hasSecondDawnChoice(content.eventChoices(
                StarterExpeditionContent.FINAL_EVENT_ID,
                chapterV7
        )));
        assertTrue(hasSecondDawnChoice(content.eventChoices(
                StarterExpeditionContent.FINAL_EVENT_ID,
                chapterV8
        )));
        assertTrue(StarterExpeditionContent.supportsSecondDawnAttunement(
                chapterV8
        ));
        assertTrue(StarterExpeditionContent.supportsSecondDawnAttunement(
                chapterV9
        ));
        assertTrue(StarterExpeditionContent.supportsSecondDawnAttunement(
                chapterV10
        ));
        assertTrue(StarterExpeditionContent.supportsSecondDawnAttunement(
                chapterV11
        ));
        assertFalse(StarterExpeditionContent.supportsSecondDawnAttunement(
                chapterV7
        ));
        assertFalse(hasUnchartedVergeChoice(content.eventChoices(
                StarterExpeditionContent.SECOND_DAWN_EVENT_ID,
                chapterV8
        )));
        List<ExpeditionEventChoiceDefinition> unchartedChoices =
                content.eventChoices(
                        StarterExpeditionContent.SECOND_DAWN_EVENT_ID,
                        chapterV9
                );
        assertTrue(hasUnchartedVergeChoice(unchartedChoices));
        assertEquals(
                3,
                unchartedChoices.stream()
                        .filter(choice -> StarterExpeditionContent
                                .UNCHARTED_VERGE_ROUTE_CHOICE_ID
                                .equals(choice.choiceId()))
                        .findFirst()
                        .orElseThrow()
                        .equipmentRequirement()
                        .minimumUpgradeLevel()
        );
        assertFalse(hasPetGuidedChoice(content.eventChoices(
                StarterExpeditionContent.UNCHARTED_VERGE_EVENT_ID,
                chapterV9
        )));
        List<ExpeditionEventChoiceDefinition> petGuidedChoices =
                content.eventChoices(
                        StarterExpeditionContent.UNCHARTED_VERGE_EVENT_ID,
                        chapterV10
                );
        assertEquals(5, petGuidedChoices.size());
        assertEquals(
                List.of("spark-v1", "moss-v1", "rune-v1"),
                petGuidedChoices.stream()
                        .filter(choice -> choice.petRequirement() != null)
                        .map(choice -> choice.petRequirement().petId())
                        .toList()
        );
        assertEquals(
                petGuidedChoices,
                content.eventChoices(
                        StarterExpeditionContent.UNCHARTED_VERGE_EVENT_ID,
                        chapterV11
                )
        );
        List<ExpeditionEventChoiceDefinition> adultFrontierChoices =
                content.eventChoices(
                        StarterExpeditionContent.UNCHARTED_VERGE_EVENT_ID,
                        chapterV12
                );
        assertEquals(8, adultFrontierChoices.size());
        assertEquals(
                List.of(2, 2, 2),
                adultFrontierChoices.stream()
                        .filter(choice -> choice.petRequirement() != null)
                        .filter(choice -> choice.petRequirement()
                                .minimumEvolutionStage() > 0)
                        .map(choice -> choice.petRequirement()
                                .minimumEvolutionStage())
                        .toList()
        );
        assertFalse(StarterExpeditionContent.supportsAdultPetEvolution(
                chapterV10
        ));
        assertTrue(StarterExpeditionContent.supportsAdultPetEvolution(
                chapterV11
        ));
        assertTrue(StarterExpeditionContent.supportsAdultPetEvolution(
                chapterV12
        ));
        assertTrue(StarterExpeditionContent.supportsAdultPetEvolution(
                chapterV13
        ));
        assertFalse(StarterExpeditionContent.supportsAdultPetFrontier(
                chapterV11
        ));
        assertTrue(StarterExpeditionContent.supportsAdultPetFrontier(
                chapterV12
        ));
        assertTrue(StarterExpeditionContent.supportsAdultPetFrontier(
                chapterV13
        ));
        assertFalse(StarterExpeditionContent.supportsPilotSkillChoice(
                chapterV12
        ));
        assertTrue(StarterExpeditionContent.supportsPilotSkillChoice(
                chapterV13
        ));
        assertTrue(StarterExpeditionContent.supportsPilotSkillChoice(
                chapterV14
        ));
        assertFalse(StarterExpeditionContent.supportsSignalReaderSecretRoute(
                chapterV13
        ));
        assertTrue(StarterExpeditionContent.supportsSignalReaderSecretRoute(
                chapterV14
        ));
        assertTrue(StarterExpeditionContent.supportsSignalReaderSecretRoute(
                chapterV15
        ));
        assertFalse(StarterExpeditionContent.supportsTrailMemoryRoute(
                chapterV14
        ));
        assertTrue(StarterExpeditionContent.supportsTrailMemoryRoute(
                chapterV15
        ));
        assertTrue(StarterExpeditionContent.supportsTrailMemoryRoute(
                chapterV16
        ));
        assertFalse(StarterExpeditionContent.supportsEnergyDisciplineRoute(
                chapterV15
        ));
        assertTrue(StarterExpeditionContent.supportsEnergyDisciplineRoute(
                chapterV16
        ));
        assertTrue(StarterExpeditionContent.supportsEnergyDisciplineRoute(
                chapterV17
        ));
        assertFalse(StarterExpeditionContent.supportsSteadyStepRoute(
                chapterV16
        ));
        assertTrue(StarterExpeditionContent.supportsSteadyStepRoute(
                chapterV17
        ));
        assertEquals(2, content.eventChoices(
                StarterExpeditionContent.CONSTELLATION_SANCTUARY_EVENT_ID,
                chapterV12
        ).size());
        var skillChoice = content.requireChoice(
                StarterExpeditionContent.CONSTELLATION_SANCTUARY_EVENT_ID,
                StarterExpeditionContent.SIGNAL_READER_SANCTUARY_CHOICE_ID,
                chapterV13
        );
        assertEquals("signal-reader", skillChoice.skillRequirement().skillId());
        assertEquals(4, skillChoice.materialReward().quantity());
        assertTrue(StarterExpeditionContent.supportsStormRift(chapterV4));
        assertTrue(StarterExpeditionContent.supportsResonanceRoute(chapterV3));
        assertEquals(
                StarterExpeditionContent.STEADY_STEP_ROUTE_NODE_COUNT,
                content.nodes().size()
        );
    }

    @Test
    void shouldRejoinMainRouteAfterStormRift() {
        var ordinaryChoice = content.eventChoices(
                StarterExpeditionContent.STORM_ARCHIVE_EVENT_ID,
                StarterExpeditionContent.CONTENT_VERSION
        ).getFirst();

        assertEquals(
                StarterExpeditionContent.EMBER_STATION_NODE_ID,
                content.nextNodeAfterEvent(
                        StarterExpeditionContent.STORM_ARCHIVE_EVENT_ID,
                        ordinaryChoice.choiceId(),
                        StarterExpeditionContent.CONTENT_VERSION
                ).orElseThrow().currentNodeId()
        );
        assertEquals(
                StarterExpeditionContent.STORM_RIFT_NODE_ID,
                content.nextNodeAfterEvent(
                        StarterExpeditionContent.STORM_ARCHIVE_EVENT_ID,
                        StarterExpeditionContent.STORM_RIFT_CHOICE_ID,
                        StarterExpeditionContent.STORM_RIFT_CONTENT_VERSION
                ).orElseThrow().currentNodeId()
        );
        assertEquals(
                StarterExpeditionContent.EMBER_STATION_NODE_ID,
                content.nextNodeAfterEvent(
                        StarterExpeditionContent.STORM_RIFT_EVENT_ID,
                        content.eventChoices(
                                StarterExpeditionContent.STORM_RIFT_EVENT_ID,
                                StarterExpeditionContent.CONTENT_VERSION
                        ).getFirst().choiceId(),
                        StarterExpeditionContent.CONTENT_VERSION
                ).orElseThrow().currentNodeId()
        );
    }

    @Test
    void shouldForkAtVoidOrchardAndRejoinAtStarWell() {
        var ordinaryChoice = content.eventChoices(
                StarterExpeditionContent.VOID_ORCHARD_EVENT_ID,
                StarterExpeditionContent.STORM_RIFT_CONTENT_VERSION
        ).getFirst();

        assertEquals(
                StarterExpeditionContent.STAR_WELL_NODE_ID,
                content.nextNodeAfterEvent(
                        StarterExpeditionContent.VOID_ORCHARD_EVENT_ID,
                        ordinaryChoice.choiceId(),
                        StarterExpeditionContent.STORM_RIFT_CONTENT_VERSION
                ).orElseThrow().currentNodeId()
        );
        assertEquals(
                StarterExpeditionContent.ROOT_MEMORY_NODE_ID,
                content.nextNodeAfterEvent(
                        StarterExpeditionContent.VOID_ORCHARD_EVENT_ID,
                        StarterExpeditionContent.ROOT_ECHO_CHOICE_ID,
                        StarterExpeditionContent.VOID_ORCHARD_CONTENT_VERSION
                ).orElseThrow().currentNodeId()
        );
        assertEquals(
                StarterExpeditionContent.LIGHT_CANOPY_NODE_ID,
                content.nextNodeAfterEvent(
                        StarterExpeditionContent.VOID_ORCHARD_EVENT_ID,
                        StarterExpeditionContent.LIGHT_CANOPY_CHOICE_ID,
                        StarterExpeditionContent.VOID_ORCHARD_CONTENT_VERSION
                ).orElseThrow().currentNodeId()
        );
        assertEquals(
                StarterExpeditionContent.STAR_WELL_NODE_ID,
                content.nextNodeAfterEvent(
                        StarterExpeditionContent.ROOT_MEMORY_EVENT_ID,
                        content.eventChoices(
                                StarterExpeditionContent.ROOT_MEMORY_EVENT_ID
                        ).getFirst().choiceId(),
                        StarterExpeditionContent.VOID_ORCHARD_CONTENT_VERSION
                ).orElseThrow().currentNodeId()
        );
        assertEquals(
                StarterExpeditionContent.STAR_WELL_NODE_ID,
                content.nextNodeAfterEvent(
                        StarterExpeditionContent.LIGHT_CANOPY_EVENT_ID,
                        content.eventChoices(
                                StarterExpeditionContent.LIGHT_CANOPY_EVENT_ID
                        ).getFirst().choiceId(),
                        StarterExpeditionContent.VOID_ORCHARD_CONTENT_VERSION
                ).orElseThrow().currentNodeId()
        );
    }

    @Test
    void shouldRouteThroughSpectrumObservatoryAndRejoinAtHorizonSpire() {
        assertEquals(
                StarterExpeditionContent.SPECTRUM_OBSERVATORY_NODE_ID,
                content.nextNodeAfterEvent(
                        StarterExpeditionContent.STAR_WELL_EVENT_ID,
                        StarterExpeditionContent.PRISM_SEXTANT_ROUTE_CHOICE_ID,
                        StarterExpeditionContent.PRISM_SEXTANT_CONTENT_VERSION
                ).orElseThrow().currentNodeId()
        );
        assertEquals(
                StarterExpeditionContent.HORIZON_SPIRE_NODE_ID,
                content.nextNodeAfterEvent(
                        StarterExpeditionContent.SPECTRUM_OBSERVATORY_EVENT_ID,
                        "chart-invisible-constellation",
                        StarterExpeditionContent.PRISM_SEXTANT_CONTENT_VERSION
                ).orElseThrow().currentNodeId()
        );
    }

    @Test
    void shouldRouteThroughSecondDawnAndCompleteAfterItsEvent() {
        assertEquals(
                StarterExpeditionContent.SECOND_DAWN_NODE_ID,
                content.nextNodeAfterEvent(
                        StarterExpeditionContent.FINAL_EVENT_ID,
                        StarterExpeditionContent.SECOND_DAWN_ROUTE_CHOICE_ID,
                        StarterExpeditionContent.SECOND_DAWN_CONTENT_VERSION
                ).orElseThrow().currentNodeId()
        );
        assertTrue(content.nextNodeAfterEvent(
                StarterExpeditionContent.SECOND_DAWN_EVENT_ID,
                "anchor-second-dawn",
                StarterExpeditionContent.SECOND_DAWN_CONTENT_VERSION
        ).isEmpty());
        assertEquals(2, content.eventChoices(
                StarterExpeditionContent.SECOND_DAWN_EVENT_ID,
                StarterExpeditionContent.SECOND_DAWN_CONTENT_VERSION
        ).size());
    }

    @Test
    void shouldCrossUnchartedVergeOnlyInChapterV9AndCompleteThere() {
        assertThrows(
                EventResolutionValidationException.class,
                () -> content.requireChoice(
                        StarterExpeditionContent.SECOND_DAWN_EVENT_ID,
                        StarterExpeditionContent.UNCHARTED_VERGE_ROUTE_CHOICE_ID,
                        StarterExpeditionContent
                                .SECOND_DAWN_ATTUNEMENT_CONTENT_VERSION
                )
        );
        assertEquals(
                StarterExpeditionContent.UNCHARTED_VERGE_NODE_ID,
                content.nextNodeAfterEvent(
                        StarterExpeditionContent.SECOND_DAWN_EVENT_ID,
                        StarterExpeditionContent.UNCHARTED_VERGE_ROUTE_CHOICE_ID,
                        StarterExpeditionContent.UNCHARTED_VERGE_CONTENT_VERSION
                ).orElseThrow().currentNodeId()
        );
        assertTrue(content.nextNodeAfterEvent(
                StarterExpeditionContent.UNCHARTED_VERGE_EVENT_ID,
                "deploy-return-beacon",
                StarterExpeditionContent.UNCHARTED_VERGE_CONTENT_VERSION
        ).isEmpty());
        assertEquals(2, content.eventChoices(
                StarterExpeditionContent.UNCHARTED_VERGE_EVENT_ID,
                StarterExpeditionContent.UNCHARTED_VERGE_CONTENT_VERSION
        ).size());
        assertThrows(
                EventResolutionValidationException.class,
                () -> content.requireChoice(
                        StarterExpeditionContent.UNCHARTED_VERGE_EVENT_ID,
                        StarterExpeditionContent.MOSS_UNCHARTED_CHOICE_ID,
                        StarterExpeditionContent.UNCHARTED_VERGE_CONTENT_VERSION
                )
        );
    }

    @Test
    void shouldOpenConstellationSanctuaryOnlyForAdultPetFrontier() {
        assertThrows(
                EventResolutionValidationException.class,
                () -> content.requireChoice(
                        StarterExpeditionContent.UNCHARTED_VERGE_EVENT_ID,
                        StarterExpeditionContent.SPARK_ADULT_FRONTIER_CHOICE_ID,
                        StarterExpeditionContent
                                .ADULT_PET_EVOLUTION_CONTENT_VERSION
                )
        );
        assertEquals(
                StarterExpeditionContent.CONSTELLATION_SANCTUARY_NODE_ID,
                content.nextNodeAfterEvent(
                        StarterExpeditionContent.UNCHARTED_VERGE_EVENT_ID,
                        StarterExpeditionContent.SPARK_ADULT_FRONTIER_CHOICE_ID,
                        StarterExpeditionContent.ADULT_PET_FRONTIER_CONTENT_VERSION
                ).orElseThrow().currentNodeId()
        );
        assertEquals(
                2,
                content.requireChoice(
                        StarterExpeditionContent.UNCHARTED_VERGE_EVENT_ID,
                        StarterExpeditionContent.SPARK_ADULT_FRONTIER_CHOICE_ID,
                        StarterExpeditionContent.ADULT_PET_FRONTIER_CONTENT_VERSION
                ).petRequirement().minimumEvolutionStage()
        );
        assertTrue(content.eventChoices(
                StarterExpeditionContent.CONSTELLATION_SANCTUARY_EVENT_ID,
                StarterExpeditionContent.ADULT_PET_EVOLUTION_CONTENT_VERSION
        ).isEmpty());
        assertEquals(2, content.eventChoices(
                StarterExpeditionContent.CONSTELLATION_SANCTUARY_EVENT_ID,
                StarterExpeditionContent.ADULT_PET_FRONTIER_CONTENT_VERSION
        ).size());
        assertThrows(
                EventResolutionValidationException.class,
                () -> content.requireChoice(
                        StarterExpeditionContent.CONSTELLATION_SANCTUARY_EVENT_ID,
                        StarterExpeditionContent.SIGNAL_READER_SANCTUARY_CHOICE_ID,
                        StarterExpeditionContent.ADULT_PET_FRONTIER_CONTENT_VERSION
                )
        );
        assertEquals(3, content.eventChoices(
                StarterExpeditionContent.CONSTELLATION_SANCTUARY_EVENT_ID,
                StarterExpeditionContent.PILOT_SKILL_CHOICE_CONTENT_VERSION
        ).size());
        assertEquals(
                "signal-reader",
                content.requireChoice(
                        StarterExpeditionContent.CONSTELLATION_SANCTUARY_EVENT_ID,
                        StarterExpeditionContent.SIGNAL_READER_SANCTUARY_CHOICE_ID,
                        StarterExpeditionContent.PILOT_SKILL_CHOICE_CONTENT_VERSION
                ).skillRequirement().skillId()
        );
        assertTrue(content.nextNodeAfterEvent(
                StarterExpeditionContent.CONSTELLATION_SANCTUARY_EVENT_ID,
                StarterExpeditionContent.SIGNAL_READER_SANCTUARY_CHOICE_ID,
                StarterExpeditionContent.PILOT_SKILL_CHOICE_CONTENT_VERSION
        ).isEmpty());
        assertEquals(
                StarterExpeditionContent.HIDDEN_SIGNAL_OBSERVATORY_NODE_ID,
                content.nextNodeAfterEvent(
                        StarterExpeditionContent
                                .CONSTELLATION_SANCTUARY_EVENT_ID,
                        StarterExpeditionContent
                                .SIGNAL_READER_SANCTUARY_CHOICE_ID,
                        StarterExpeditionContent
                                .SIGNAL_READER_SECRET_ROUTE_CONTENT_VERSION
                ).orElseThrow().currentNodeId()
        );
        assertEquals(2, content.eventChoices(
                StarterExpeditionContent.HIDDEN_SIGNAL_OBSERVATORY_EVENT_ID,
                StarterExpeditionContent.PILOT_SKILL_CHOICE_CONTENT_VERSION
        ).size());
        assertEquals(2, content.eventChoices(
                StarterExpeditionContent.HIDDEN_SIGNAL_OBSERVATORY_EVENT_ID,
                StarterExpeditionContent
                        .SIGNAL_READER_SECRET_ROUTE_CONTENT_VERSION
        ).size());
        assertEquals(3, content.eventChoices(
                StarterExpeditionContent.HIDDEN_SIGNAL_OBSERVATORY_EVENT_ID,
                StarterExpeditionContent.TRAIL_MEMORY_ROUTE_CONTENT_VERSION
        ).size());
        assertThrows(
                EventResolutionValidationException.class,
                () -> content.requireChoice(
                        StarterExpeditionContent
                                .HIDDEN_SIGNAL_OBSERVATORY_EVENT_ID,
                        StarterExpeditionContent
                                .RECONSTRUCT_FORGOTTEN_ROUTE_CHOICE_ID,
                        StarterExpeditionContent
                                .SIGNAL_READER_SECRET_ROUTE_CONTENT_VERSION
                )
        );
        assertEquals(
                PlatformSkillIds.TRAIL_MEMORY,
                content.requireChoice(
                        StarterExpeditionContent
                                .HIDDEN_SIGNAL_OBSERVATORY_EVENT_ID,
                        StarterExpeditionContent
                                .RECONSTRUCT_FORGOTTEN_ROUTE_CHOICE_ID,
                        StarterExpeditionContent
                                .TRAIL_MEMORY_ROUTE_CONTENT_VERSION
                ).skillRequirement().skillId()
        );
        assertEquals(
                StarterExpeditionContent.MEMORY_CONSTELLATION_NODE_ID,
                content.nextNodeAfterEvent(
                        StarterExpeditionContent
                                .HIDDEN_SIGNAL_OBSERVATORY_EVENT_ID,
                        StarterExpeditionContent
                                .RECONSTRUCT_FORGOTTEN_ROUTE_CHOICE_ID,
                        StarterExpeditionContent
                                .TRAIL_MEMORY_ROUTE_CONTENT_VERSION
                ).orElseThrow().currentNodeId()
        );
        assertEquals(2, content.eventChoices(
                StarterExpeditionContent.MEMORY_CONSTELLATION_EVENT_ID,
                StarterExpeditionContent
                        .SIGNAL_READER_SECRET_ROUTE_CONTENT_VERSION
        ).size());
        assertEquals(2, content.eventChoices(
                StarterExpeditionContent.MEMORY_CONSTELLATION_EVENT_ID,
                StarterExpeditionContent.TRAIL_MEMORY_ROUTE_CONTENT_VERSION
        ).size());
        assertEquals(3, content.eventChoices(
                StarterExpeditionContent.MEMORY_CONSTELLATION_EVENT_ID,
                StarterExpeditionContent
                        .ENERGY_DISCIPLINE_ROUTE_CONTENT_VERSION
        ).size());
        assertThrows(
                EventResolutionValidationException.class,
                () -> content.requireChoice(
                        StarterExpeditionContent.MEMORY_CONSTELLATION_EVENT_ID,
                        StarterExpeditionContent.STABILIZE_DAWN_CURRENT_CHOICE_ID,
                        StarterExpeditionContent.TRAIL_MEMORY_ROUTE_CONTENT_VERSION
                )
        );
        assertEquals(
                PlatformSkillIds.ENERGY_DISCIPLINE,
                content.requireChoice(
                        StarterExpeditionContent.MEMORY_CONSTELLATION_EVENT_ID,
                        StarterExpeditionContent.STABILIZE_DAWN_CURRENT_CHOICE_ID,
                        StarterExpeditionContent
                                .ENERGY_DISCIPLINE_ROUTE_CONTENT_VERSION
                ).skillRequirement().skillId()
        );
        assertEquals(
                StarterExpeditionContent.DAWN_MERIDIAN_NODE_ID,
                content.nextNodeAfterEvent(
                        StarterExpeditionContent.MEMORY_CONSTELLATION_EVENT_ID,
                        StarterExpeditionContent.STABILIZE_DAWN_CURRENT_CHOICE_ID,
                        StarterExpeditionContent
                                .ENERGY_DISCIPLINE_ROUTE_CONTENT_VERSION
                ).orElseThrow().currentNodeId()
        );
        assertEquals(2, content.eventChoices(
                StarterExpeditionContent.DAWN_MERIDIAN_EVENT_ID,
                StarterExpeditionContent.TRAIL_MEMORY_ROUTE_CONTENT_VERSION
        ).size());
        assertEquals(2, content.eventChoices(
                StarterExpeditionContent.DAWN_MERIDIAN_EVENT_ID,
                StarterExpeditionContent
                        .ENERGY_DISCIPLINE_ROUTE_CONTENT_VERSION
        ).size());
        assertEquals(3, content.eventChoices(
                StarterExpeditionContent.DAWN_MERIDIAN_EVENT_ID,
                StarterExpeditionContent.STEADY_STEP_ROUTE_CONTENT_VERSION
        ).size());
        assertThrows(
                EventResolutionValidationException.class,
                () -> content.requireChoice(
                        StarterExpeditionContent.DAWN_MERIDIAN_EVENT_ID,
                        StarterExpeditionContent
                                .CROSS_FIRST_LIGHT_CAUSEWAY_CHOICE_ID,
                        StarterExpeditionContent
                                .ENERGY_DISCIPLINE_ROUTE_CONTENT_VERSION
                )
        );
        assertEquals(
                PlatformSkillIds.STEADY_STEP,
                content.requireChoice(
                        StarterExpeditionContent.DAWN_MERIDIAN_EVENT_ID,
                        StarterExpeditionContent
                                .CROSS_FIRST_LIGHT_CAUSEWAY_CHOICE_ID,
                        StarterExpeditionContent.STEADY_STEP_ROUTE_CONTENT_VERSION
                ).skillRequirement().skillId()
        );
        assertEquals(
                StarterExpeditionContent.FIRST_LIGHT_CAUSEWAY_NODE_ID,
                content.nextNodeAfterEvent(
                        StarterExpeditionContent.DAWN_MERIDIAN_EVENT_ID,
                        StarterExpeditionContent
                                .CROSS_FIRST_LIGHT_CAUSEWAY_CHOICE_ID,
                        StarterExpeditionContent.STEADY_STEP_ROUTE_CONTENT_VERSION
                ).orElseThrow().currentNodeId()
        );
        assertEquals(2, content.eventChoices(
                StarterExpeditionContent.FIRST_LIGHT_CAUSEWAY_EVENT_ID,
                StarterExpeditionContent
                        .ENERGY_DISCIPLINE_ROUTE_CONTENT_VERSION
        ).size());
        assertTrue(content.nextNodeAfterEvent(
                StarterExpeditionContent.FIRST_LIGHT_CAUSEWAY_EVENT_ID,
                StarterExpeditionContent.MAP_FIRST_LIGHT_PULSE_CHOICE_ID,
                StarterExpeditionContent
                        .ENERGY_DISCIPLINE_ROUTE_CONTENT_VERSION
        ).isEmpty());
        assertTrue(content.nextNodeAfterEvent(
                StarterExpeditionContent.DAWN_MERIDIAN_EVENT_ID,
                StarterExpeditionContent.ANCHOR_DAWN_FLOW_CHOICE_ID,
                StarterExpeditionContent.TRAIL_MEMORY_ROUTE_CONTENT_VERSION
        ).isEmpty());
        assertTrue(content.nextNodeAfterEvent(
                StarterExpeditionContent.MEMORY_CONSTELLATION_EVENT_ID,
                StarterExpeditionContent.ENTRUST_MEMORY_TO_PET_CHOICE_ID,
                StarterExpeditionContent
                        .SIGNAL_READER_SECRET_ROUTE_CONTENT_VERSION
        ).isEmpty());
        assertTrue(content.nextNodeAfterEvent(
                StarterExpeditionContent.HIDDEN_SIGNAL_OBSERVATORY_EVENT_ID,
                StarterExpeditionContent.CHART_HIDDEN_SECTOR_CHOICE_ID,
                StarterExpeditionContent
                        .SIGNAL_READER_SECRET_ROUTE_CONTENT_VERSION
        ).isEmpty());
        assertTrue(content.nextNodeAfterEvent(
                StarterExpeditionContent.HIDDEN_SIGNAL_OBSERVATORY_EVENT_ID,
                StarterExpeditionContent.PRESERVE_ECHO_KEY_CHOICE_ID,
                StarterExpeditionContent.PILOT_SKILL_CHOICE_CONTENT_VERSION
        ).isEmpty());
        assertTrue(content.nextNodeAfterEvent(
                StarterExpeditionContent.CONSTELLATION_SANCTUARY_EVENT_ID,
                "anchor-constellation-sanctuary",
                StarterExpeditionContent.ADULT_PET_FRONTIER_CONTENT_VERSION
        ).isEmpty());
    }

    private boolean hasStormRiftChoice(
            List<ExpeditionEventChoiceDefinition> choices
    ) {
        return choices.stream().anyMatch(choice ->
                StarterExpeditionContent.STORM_RIFT_CHOICE_ID.equals(
                        choice.choiceId()
                )
        );
    }

    private boolean hasVoidOrchardChoice(
            List<ExpeditionEventChoiceDefinition> choices
    ) {
        return choices.stream().anyMatch(choice ->
                StarterExpeditionContent.ROOT_ECHO_CHOICE_ID.equals(
                        choice.choiceId()
                ) || StarterExpeditionContent.LIGHT_CANOPY_CHOICE_ID.equals(
                        choice.choiceId()
                )
        );
    }

    private boolean hasPrismSextantChoice(
            List<ExpeditionEventChoiceDefinition> choices
    ) {
        return choices.stream().anyMatch(choice ->
                StarterExpeditionContent.PRISM_SEXTANT_ROUTE_CHOICE_ID.equals(
                        choice.choiceId()
                )
        );
    }

    private boolean hasCalibratedSextantChoice(
            List<ExpeditionEventChoiceDefinition> choices
    ) {
        return choices.stream().anyMatch(choice ->
                StarterExpeditionContent.CALIBRATED_SEXTANT_CHOICE_ID.equals(
                        choice.choiceId()
                )
        );
    }

    private boolean hasSecondDawnChoice(
            List<ExpeditionEventChoiceDefinition> choices
    ) {
        return choices.stream().anyMatch(choice ->
                StarterExpeditionContent.SECOND_DAWN_ROUTE_CHOICE_ID.equals(
                        choice.choiceId()
                )
        );
    }

    private boolean hasUnchartedVergeChoice(
            List<ExpeditionEventChoiceDefinition> choices
    ) {
        return choices.stream().anyMatch(choice ->
                StarterExpeditionContent.UNCHARTED_VERGE_ROUTE_CHOICE_ID.equals(
                        choice.choiceId()
                )
        );
    }

    private boolean hasPetGuidedChoice(
            List<ExpeditionEventChoiceDefinition> choices
    ) {
        return choices.stream().anyMatch(choice ->
                choice.petRequirement() != null
        );
    }
}
